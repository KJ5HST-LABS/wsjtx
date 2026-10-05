module decoder_engine
  use, intrinsic :: iso_c_binding
  use decoder_engine_types
  use packjt77, only: pack77_state,initialize_pack77_state,reset_pack77_state
  use ft8_engine_kernel, only: ft8_kernel_state,params_block,run_ft8_kernel,reset_ft8_kernel,release_ft8_input
  use decoder_callbacks, only: decoder_callback_context,counting_ft4_decoder,ft4_decoded, &
       counting_jt9_decoder,jt9_decoded,counting_jt65_decoder,jt65_decoded
  use jt65_decode, only: jt65_options,jt65_average_entry
  use jt65_host_support, only: load_jt65_calls,write_jt65_averages
  use decode_completion_module, only: decode_completion_result,set_decode_completion,write_decode_progress
  use prog_args, only: temp_dir
  use timer_module, only: timer
  implicit none
  private
  public :: engine_host_decode
  integer(c_int), parameter :: ok=0,invalid=1,busy=2,unsupported=3,capacity=4
  integer, parameter :: evidence_capacity=1024

  type, bind(C) :: engine_options
     integer(c_int) :: abi_version
  end type
  type, bind(C) :: engine_capabilities
     integer(c_int) :: abi_version,supported_modes,cancellation,concurrent_sessions,evidence_capacity
  end type
  type, bind(C) :: ft8_options
     integer(c_int) :: half_symbol_stage=50
     integer(c_int) :: reuse_spectrum=0
     integer(c_int) :: utc=0
     integer(c_int) :: qso_progress=0
     integer(c_int) :: receive_frequency_hz=0
     integer(c_int) :: transmit_frequency_hz=0
     integer(c_int) :: search_low_hz=0
     integer(c_int) :: search_high_hz=0
     integer(c_int) :: tolerance_hz=0
     integer(c_int) :: depth=0
     integer(c_int) :: ap_width_hz=0
     integer(c_int) :: contest=0
     integer(c_int) :: candidate_thinning=0
     integer(c_int) :: time_center=0
     integer(c_int) :: cycles=0
     integer(c_int) :: trials=0
     integer(c_int) :: last_transmit=0
     integer(c_int) :: delay=0
     integer(c_int) :: threads=0
     integer(c_int) :: receive_sensitivity=0
     integer(c_int) :: discard_leading_seconds=0
     integer(c_int) :: date=0
     integer(c_int) :: ap_enabled=0
     integer(c_int) :: cq_only=0
     integer(c_int) :: even_sequence=0
     integer(c_int) :: superfox=0
     integer(c_int) :: filtered_retry=0
     integer(c_int) :: stop_hint=0
     integer(c_int) :: mtd=0
     integer(c_int) :: low_threshold=0
     integer(c_int) :: subtract_pass=0
     integer(c_int) :: transmitting=0
     integer(c_int) :: hide_duplicates=0
     integer(c_int) :: hound=0
     integer(c_int) :: standard_mycall=0
     integer(c_int) :: standard_hiscall=0
     integer(c_int) :: ap_mycall=0
     integer(c_int) :: mode_changed=0
     integer(c_int) :: band_changed=0
     integer(c_int) :: dx_search=0
     integer(c_int) :: wide_dx_search=0
     integer(c_int) :: multiple_instances=0
     integer(c_int) :: skip_first_message=0
     real(c_float) :: eme_delay_seconds=0
     character(c_char) :: mycall(12)=' '
     character(c_char) :: my_base_call(12)=' '
     character(c_char) :: hiscall(12)=' '
     character(c_char) :: his_base_call(12)=' '
     character(c_char) :: mygrid(6)=' '
     character(c_char) :: hisgrid(6)=' '
  end type
  type, bind(C) :: ft4_options
     integer(c_int) :: utc=0
     integer(c_int) :: qso_progress=0
     integer(c_int) :: receive_frequency_hz=0
     integer(c_int) :: search_low_hz=0
     integer(c_int) :: search_high_hz=0
     integer(c_int) :: depth=0
     integer(c_int) :: cq_only=0
     integer(c_int) :: contest=0
     character(c_char) :: mycall(12)=' '
     character(c_char) :: hiscall(12)=' '
  end type
  type, bind(C) :: jt9_options
     integer(c_int) :: utc=0
     integer(c_int) :: receive_frequency_hz=0
     integer(c_int) :: search_low_hz=0
     integer(c_int) :: search_high_hz=0
     integer(c_int) :: tolerance_hz=0
     integer(c_int) :: depth=0
     integer(c_int) :: submode=0
  end type
  type, bind(C) :: engine_jt65_options
     integer(c_int) :: utc=0,qso_progress=0,receive_frequency_hz=0,search_low_hz=0,search_high_hz=0
     integer(c_int) :: tolerance_hz=0,depth=0,submode=0,min_sync=0,passes=0,trials=0,aggressiveness=0
     integer(c_int) :: single_decode=0,vhf=0,averaging=0,auto_clear=0,deep_search=0,ap_enabled=0
     character(c_char) :: mycall(12)=' ',hiscall(12)=' ',hisgrid(6)=' '
  end type
  type, bind(C) :: engine_jt65_call
     character(c_char) :: call(12),grid(4)
  end type
  type, bind(C) :: engine_jt65_average_entry
     integer(c_int) :: utc,frequency_hz,polarity,used
     real(c_float) :: sync,dt_seconds
  end type
  type, bind(C) :: attempt_request
     integer(c_int64_t) :: input_id=0,analysis_id=0
     integer(c_int) :: attempt_no=0,mode=8,phase=2,source=0
     type(ft8_options) :: ft8
     type(ft4_options) :: ft4
     type(jt9_options) :: jt9
     type(engine_jt65_options) :: jt65
  end type
  type, bind(C) :: audio_view
     type(c_ptr) :: samples
     integer(c_int) :: sample_count,sample_rate_hz
  end type
  type, bind(C) :: attempt_outcome
     integer(c_int) :: status=ok,observation_count=0,retained_count=0,evidence_dropped=0
  end type
  abstract interface
     subroutine observation_callback(observation,user) bind(C)
       import :: engine_observation,c_ptr
       type(engine_observation), intent(in) :: observation
       type(c_ptr), value :: user
     end subroutine
  end interface
  type :: engine_session
     type(pack77_state) :: knowledge
     type(ft8_kernel_state) :: kernel
     type(counting_ft4_decoder) :: ft4
     ! GCC 13 can finalize an uninitialized temporary for an embedded finalizable extension.
     type(counting_jt9_decoder), allocatable :: jt9
     type(counting_jt65_decoder), allocatable :: jt65
     type(attempt_request) :: request
     type(engine_observation), allocatable :: evidence(:)
     integer(c_short), allocatable :: audio(:)
     integer(c_int64_t) :: input_id=0,analysis_id=0
     integer :: input_mode=0
     integer :: last_attempt=0,retained=0,dropped=0,emitted=0
     logical :: running=.false.,render_legacy=.false.
     type(c_funptr) :: callback=c_null_funptr
     type(c_ptr) :: user=c_null_ptr
     type(decode_completion_result) :: completion
  end type
  type(engine_session), allocatable, target, save :: session
  integer(c_int), target, save :: token=1
  type(c_ptr), save :: host_handle=c_null_ptr
  integer(c_int64_t), save :: fallback_input=0,fallback_analysis=0
  integer, save :: fallback_utc=-1

contains

  pure integer function analysis_extent(mode) result(samples)
    integer, intent(in) :: mode
    select case(mode)
    case(engine_mode_ft4)
       samples=72576
    case(engine_mode_ft8)
       samples=180000
    case(engine_mode_jt9,engine_mode_jt65)
       samples=720000
    case default
       samples=0
    end select
  end function analysis_extent

  subroutine initialize_session(state)
    type(engine_session), intent(inout) :: state
    allocate(state%jt9)
    allocate(state%jt65)
    allocate(state%audio(analysis_extent(engine_mode_ft8)),state%evidence(evidence_capacity))
    state%audio=0
    call initialize_pack77_state(state%knowledge)
    call reset_ft8_kernel(state%kernel)
  end subroutine initialize_session

  logical function valid_handle(handle)
    type(c_ptr), value :: handle
    valid_handle=allocated(session).and.c_associated(handle,c_loc(token))
  end function

  integer(c_int) function engine_create(options,handle) bind(C,name='decoder_engine_create') result(status)
    type(engine_options), intent(in) :: options
    type(c_ptr), intent(out) :: handle
    handle=c_null_ptr
    status=unsupported
    if(options%abi_version/=engine_abi) return
    status=busy
    if(allocated(session)) return
    allocate(session)
    call initialize_session(session)
    handle=c_loc(token)
    status=ok
  end function

  integer(c_int) function engine_get_capabilities(handle,caps) &
       bind(C,name='decoder_engine_get_capabilities') result(status)
    type(c_ptr), value :: handle
    type(engine_capabilities), intent(out) :: caps
    caps=engine_capabilities(engine_abi, &
         ior(ior(engine_support_ft8,engine_support_ft4),ior(engine_support_jt9,engine_support_jt65)), &
         0,0,evidence_capacity)
    status=invalid
    if(valid_handle(handle)) status=ok
  end function

  recursive integer(c_int) function engine_decode(handle,request,audio,callback,user,outcome) &
       bind(C,name='decoder_engine_decode') result(status)
    type(c_ptr), value :: handle,user
    type(attempt_request), intent(in) :: request
    type(audio_view), intent(in) :: audio
    type(c_funptr), value :: callback
    type(attempt_outcome), intent(out) :: outcome
    status=decode_attempt(handle,request,audio,callback,user,outcome,.false.,0)
  end function

  recursive integer(c_int) function decode_attempt(handle,request,audio,callback,user,outcome,render,progress) result(status)
    type(c_ptr), intent(in) :: handle,user
    type(attempt_request), intent(in) :: request
    type(audio_view), intent(in) :: audio
    type(c_funptr), intent(in) :: callback
    type(attempt_outcome), intent(out) :: outcome
    logical, intent(in) :: render
    integer, intent(in) :: progress
    integer(c_short), pointer :: samples(:)
    integer :: analysis_samples
    type(params_block) :: params
    type(decoder_callback_context) :: context
    outcome=attempt_outcome()
    status=invalid
    if(.not.valid_handle(handle)) go to 900
    status=busy
    if(session%running) go to 900
    status=unsupported
    if(request%mode/=engine_mode_ft8.and.request%mode/=engine_mode_ft4.and. &
         request%mode/=engine_mode_jt9.and.request%mode/=engine_mode_jt65) go to 900
    if(audio%sample_rate_hz/=12000) go to 900
    status=invalid
    if(request%input_id<=0.or.request%analysis_id<=0.or.request%attempt_no<=0) go to 900
    if(request%phase<1.or.request%phase>3.or.request%source<0.or.request%source>1) go to 900
    analysis_samples=analysis_extent(request%mode)
    if(audio%sample_count<1.or.audio%sample_count>analysis_samples) go to 900
    if(.not.c_associated(audio%samples)) go to 900
    if(request%mode==engine_mode_ft4) then
       if(request%phase==1) go to 900
       if(request%ft4%search_low_hz<0.or.request%ft4%search_high_hz>6000.or. &
            request%ft4%search_low_hz>request%ft4%search_high_hz) go to 900
       if(request%ft4%depth<1.or.request%ft4%depth>3) go to 900
       if(request%ft4%qso_progress<0.or.request%ft4%qso_progress>5) go to 900
       if(request%ft4%contest<0.or.request%ft4%contest>7) go to 900
       if(request%ft4%cq_only<0.or.request%ft4%cq_only>1) go to 900
    else if(request%mode==engine_mode_jt9) then
       if(request%phase==1) go to 900
       if(request%jt9%search_low_hz<0.or.request%jt9%search_high_hz>5000.or. &
            request%jt9%search_low_hz>request%jt9%search_high_hz) go to 900
       if(request%jt9%receive_frequency_hz<0.or.request%jt9%receive_frequency_hz>5000) go to 900
       if(request%jt9%tolerance_hz<0.or.request%jt9%tolerance_hz>5000) go to 900
       if(request%jt9%depth<1.or.request%jt9%depth>3) go to 900
       if(request%jt9%submode<0.or.request%jt9%submode>7) go to 900
    else if(request%mode==engine_mode_jt65) then
       if(request%phase==1) go to 900
       if(.not.valid_jt65_options(request%jt65)) go to 900
    else
       if(request%ft8%search_low_hz<0.or.request%ft8%search_high_hz>6000.or. &
            request%ft8%search_low_hz>request%ft8%search_high_hz) go to 900
       if(request%ft8%half_symbol_stage<41.or.request%ft8%half_symbol_stage>50) go to 900
       if(request%ft8%reuse_spectrum<0.or.request%ft8%reuse_spectrum>1) go to 900
       if(request%ft8%threads<0.or.request%ft8%threads>24) go to 900
    endif
    if(session%input_id/=0.and.session%input_id/=request%input_id) go to 900
    if(session%input_id/=0.and.session%input_mode/=request%mode) go to 900
    if(session%analysis_id==request%analysis_id.and.request%attempt_no<=session%last_attempt) go to 900

    if(size(session%audio)<analysis_samples) then
       deallocate(session%audio)
       allocate(session%audio(analysis_samples))
    endif
    session%running=.true.
    session%request=request
    session%input_id=request%input_id
    session%input_mode=request%mode
    session%analysis_id=request%analysis_id
    session%last_attempt=request%attempt_no
    session%callback=callback
    session%user=user
    session%render_legacy=render
    session%emitted=0
    call c_f_pointer(audio%samples,samples,[audio%sample_count])
    session%audio(1:audio%sample_count)=samples
    session%audio(audio%sample_count+1:analysis_samples)=0
    context%sink=>collect_observation
    context%superfox_sink=>collect_superfox
    context%sink_user=handle
    context%render_legacy=render
    if(request%mode==engine_mode_ft4) then
       call run_ft4_attempt(request%ft4,request%phase,context,progress)
    else if(request%mode==engine_mode_jt9) then
       call run_jt9_attempt(request%jt9,request%phase,audio%sample_count,context,progress)
    else if(request%mode==engine_mode_jt65) then
       call run_jt65_attempt(request%jt65,request%phase,audio%sample_count,context,progress)
    else
       call request_to_params(request,audio%sample_count,params)
       call run_ft8_kernel(session%kernel,session%knowledge,session%audio(:180000), &
            params,session%completion,progress,context)
    endif
    outcome%observation_count=session%emitted
    outcome%retained_count=session%retained
    outcome%evidence_dropped=session%dropped
    session%callback=c_null_funptr
    session%user=c_null_ptr
    session%running=.false.
    status=ok
900 outcome%status=status
  end function

  subroutine open_legacy_output(phase,ios)
    integer, intent(in) :: phase
    integer, intent(out) :: ios
    integer :: tries

    do tries=1,4
       if(phase==3) then
          open(13,file=trim(temp_dir)//'/decoded.txt',status='unknown',position='append',iostat=ios)
       else
          open(13,file=trim(temp_dir)//'/decoded.txt',status='unknown',iostat=ios)
       endif
       if(ios==0) exit
       if(tries<4) call sleep_msec(10)
    enddo
  end subroutine open_legacy_output

  subroutine run_ft4_attempt(options,phase,callback_context,progress)
    type(ft4_options), intent(in) :: options
    integer, intent(in) :: phase,progress
    type(decoder_callback_context), intent(in) :: callback_context
    type(decoder_callback_context) :: context
    character(len=12) :: mycall,hiscall

    context=callback_context
    context%nutc=options%utc
    context%nfqso=options%receive_frequency_hz
    context%ncontest=options%contest
    context%ios13=-1
    if(context%render_legacy) call open_legacy_output(phase,context%ios13)
    session%ft4%context=context
    session%ft4%decoded=0
    mycall=transfer(options%mycall,mycall)
    hiscall=transfer(options%hiscall,hiscall)
    if(any(session%audio(:72576)/=0)) then
       call timer('decft4  ',0)
       call session%ft4%decode(ft4_decoded,session%audio(:72576),options%qso_progress, &
            options%receive_frequency_hz,options%search_low_hz,options%search_high_hz, &
            options%depth,options%cq_only/=0,options%contest,mycall,hiscall,session%knowledge)
       call timer('decft4  ',1)
    endif
    call set_decode_completion(session%completion,0,session%ft4%decoded,0)
    call write_decode_progress(progress)
    if(context%ios13==0) close(13)
  end subroutine

  subroutine run_jt9_attempt(options,phase,sample_count,callback_context,progress)
    type(jt9_options), intent(in) :: options
    integer, intent(in) :: phase,sample_count,progress
    type(decoder_callback_context), intent(in) :: callback_context
    type(decoder_callback_context) :: context

    context=callback_context
    context%nutc=options%utc
    context%nfqso=options%receive_frequency_hz
    context%submode=options%submode
    context%ios13=-1
    session%jt9%decoded=0
    if(sqrt(sum(real(session%audio(:sample_count))**2)/real(sample_count))<0.5) go to 100
    if(context%render_legacy) call open_legacy_output(phase,context%ios13)
    session%jt9%context=context
    call timer('decjt9  ',0)
    call session%jt9%decode_pcm(jt9_decoded,session%audio,sample_count,options%receive_frequency_hz, &
         options%search_low_hz,options%search_high_hz,options%tolerance_hz,options%depth, &
         options%submode,phase==3)
    call timer('decjt9  ',1)
    if(context%ios13==0) close(13)
100 call set_decode_completion(session%completion,0,session%jt9%decoded,0)
    call write_decode_progress(progress)
  end subroutine

  logical function valid_jt65_options(options) result(valid)
    type(engine_jt65_options), intent(in) :: options
    valid=.false.
    if(options%search_low_hz<0.or.options%search_high_hz>5000.or. &
         options%search_low_hz>options%search_high_hz) return
    if(options%receive_frequency_hz<0.or.options%receive_frequency_hz>5000) return
    if(options%tolerance_hz<0.or.options%tolerance_hz>5000) return
    if(options%depth<1.or.options%depth>3.or.options%submode<0.or.options%submode>2) return
    if(options%passes<1.or.options%passes>2) return
    if(options%trials<0.or.options%trials>1000000) return
    if(options%aggressiveness<0.or.options%aggressiveness>11) return
    if(options%qso_progress<0.or.options%qso_progress>5) return
    if(any([options%single_decode,options%vhf,options%averaging,options%auto_clear, &
         options%deep_search,options%ap_enabled]<0)) return
    if(any([options%single_decode,options%vhf,options%averaging,options%auto_clear, &
         options%deep_search,options%ap_enabled]>1)) return
    valid=.true.
  end function

  subroutine run_jt65_attempt(options,phase,sample_count,callback_context,progress)
    type(engine_jt65_options), intent(in) :: options
    integer, intent(in) :: phase,sample_count,progress
    type(decoder_callback_context), intent(in) :: callback_context
    type(decoder_callback_context) :: context
    type(jt65_options) :: kernel_options
    logical, external :: baddata

    context=callback_context
    context%nutc=options%utc
    context%nfqso=options%receive_frequency_hz
    context%submode=options%submode
    context%bVHF=options%vhf/=0
    context%ios13=-1
    context%ios14=-1
    if(context%render_legacy) then
       call open_legacy_output(phase,context%ios13)
       open(14,file=trim(temp_dir)//'/avemsg.txt',status='unknown',iostat=context%ios14)
    endif
    session%jt65%context=context
    session%jt65%decoded=0
    kernel_options%utc=options%utc
    kernel_options%low_frequency=options%search_low_hz
    kernel_options%high_frequency=options%search_high_hz
    kernel_options%receive_frequency=options%receive_frequency_hz
    kernel_options%tolerance=options%tolerance_hz
    kernel_options%submode=options%submode
    kernel_options%min_sync=options%min_sync
    kernel_options%passes=options%passes
    kernel_options%trials=options%trials
    kernel_options%aggressiveness=options%aggressiveness
    kernel_options%effort=options%depth
    kernel_options%qso_progress=options%qso_progress
    kernel_options%repeat=phase==3
    kernel_options%single_decode=options%single_decode/=0
    kernel_options%vhf=options%vhf/=0
    kernel_options%average=options%averaging/=0
    kernel_options%auto_clear=options%auto_clear/=0
    kernel_options%deep_search=options%deep_search/=0
    kernel_options%ap=options%ap_enabled/=0
    kernel_options%mycall=transfer(options%mycall,kernel_options%mycall)
    kernel_options%hiscall=transfer(options%hiscall,kernel_options%hiscall)
    kernel_options%hisgrid=transfer(options%hisgrid,kernel_options%hisgrid)
    call timer('decjt65 ',0)
    if(.not.baddata(session%audio,52*12000)) then
      call session%jt65%decode_pcm(jt65_decoded,session%audio,sample_count,kernel_options,session%input_id)
    endif
    call timer('decjt65 ',1)
    if(context%ios14==0) then
       call write_jt65_averages(session%jt65,14)
       close(14)
    endif
    if(context%ios13==0) close(13)
    call set_decode_completion(session%completion,0,session%jt65%decoded,0)
    call write_decode_progress(progress)
  end subroutine

  integer(c_int) function engine_set_jt65_calls(handle,entries,count) &
       bind(C,name='decoder_engine_set_jt65_calls') result(status)
    type(c_ptr), value :: handle,entries
    integer(c_int), value :: count
    type(engine_jt65_call), pointer :: records(:)
    character(len=12), allocatable :: calls(:)
    character(len=4), allocatable :: grids(:)
    integer :: i
    status=invalid
    if(.not.valid_handle(handle)) return
    status=busy
    if(session%running) return
    status=invalid
    if(count<0.or.count>10000) return
    if(count>0.and..not.c_associated(entries)) return
    allocate(calls(count),grids(count))
    if(count>0) then
       call c_f_pointer(entries,records,[count])
       do i=1,count
          calls(i)=transfer(records(i)%call,calls(i))
          grids(i)=transfer(records(i)%grid,grids(i))
       enddo
    endif
    call session%jt65%set_calls(calls,grids)
    status=ok
  end function

  integer(c_int) function engine_get_jt65_averages(handle,entries,entry_capacity,count) &
       bind(C,name='decoder_engine_get_jt65_averages') result(status)
    type(c_ptr), value :: handle,entries
    integer(c_int), value :: entry_capacity
    integer(c_int), intent(out) :: count
    type(engine_jt65_average_entry), pointer :: records(:)
    type(jt65_average_entry) :: averages(64)
    integer :: i,n
    count=0
    status=invalid
    if(.not.valid_handle(handle)) return
    status=busy
    if(session%running) return
    status=invalid
    if(entry_capacity<0) return
    if(entry_capacity>0.and..not.c_associated(entries)) return
    call session%jt65%get_averages(averages,n)
    count=n
    if(entry_capacity>0) then
       call c_f_pointer(entries,records,[entry_capacity])
       do i=1,min(entry_capacity,n)
          records(i)%utc=averages(i)%utc
          records(i)%frequency_hz=averages(i)%frequency
          records(i)%polarity=averages(i)%polarity
          records(i)%used=merge(1,0,averages(i)%used)
          records(i)%sync=averages(i)%sync
          records(i)%dt_seconds=averages(i)%dt
       enddo
    endif
    status=ok
    if(entry_capacity>0.and.entry_capacity<n) status=capacity
  end function

  integer(c_int) function engine_clear_jt65_averages(handle) &
       bind(C,name='decoder_engine_clear_jt65_averages') result(status)
    type(c_ptr), value :: handle
    status=invalid
    if(.not.valid_handle(handle)) return
    status=busy
    if(session%running) return
    call session%jt65%clear_averages()
    status=ok
  end function

  subroutine collect_observation(user,observation)
    type(c_ptr), intent(in) :: user
    type(engine_observation), intent(in) :: observation
    type(engine_observation) :: record
    procedure(observation_callback), pointer :: callback
    if(.not.valid_handle(user)) return
    record=observation
    record%input_id=session%request%input_id
    record%analysis_id=session%request%analysis_id
    record%attempt_no=session%request%attempt_no
    session%emitted=session%emitted+1
    if(session%retained<evidence_capacity) then
       session%retained=session%retained+1
       session%evidence(session%retained)=record
    else
       session%dropped=session%dropped+1
    endif
    if(c_associated(session%callback)) then
       call c_f_procpointer(session%callback,callback)
       call callback(record,session%user)
    endif
  end subroutine

  subroutine collect_superfox(user,observation)
    type(c_ptr), intent(in) :: user
    type(superfox_observation), intent(in) :: observation
    type(engine_observation) :: record
    integer :: i
    record%variant=2
    record%superfox%kind=observation%kind
    record%superfox%child_index=observation%child_index
    record%snr_db=observation%snr_db
    record%frequency_hz=observation%frequency_hz
    record%dt_seconds=observation%dt_seconds
    record%superfox%symbols=observation%symbols
    do i=1,min(37,len_trim(observation%message))
       record%message(i)=observation%message(i:i)
    enddo
    call collect_observation(user,record)
    if(session%render_legacy.and.observation%legacy_line_length>0) then
       write(*,'(a)') observation%legacy_line(:observation%legacy_line_length)
       flush(6)
    endif
  end subroutine

  integer(c_int) function engine_release_input(handle,input_id) &
       bind(C,name='decoder_engine_release_input') result(status)
    type(c_ptr), value :: handle
    integer(c_int64_t), value :: input_id
    status=invalid
    if(.not.valid_handle(handle)) return
    status=busy
    if(session%running) return
    status=invalid
    if(input_id<=0.or.session%input_id/=input_id) return
    call release_ft8_input(session%kernel)
    call session%jt9%release_input()
    call session%jt65%release_input()
    session%audio=0
    session%input_id=0
    session%input_mode=0
    session%analysis_id=0
    session%last_attempt=0
    session%retained=0
    session%dropped=0
    status=ok
  end function

  integer(c_int) function engine_reset_session(handle) bind(C,name='decoder_engine_reset_session') result(status)
    type(c_ptr), value :: handle
    status=invalid
    if(.not.valid_handle(handle)) return
    status=busy
    if(session%running) return
    call reset_ft8_kernel(session%kernel)
    call session%ft4%reset()
    call session%jt9%reset()
    call session%jt65%reset()
    call reset_pack77_state(session%knowledge)
    session%audio=0
    session%input_id=0
    session%input_mode=0
    session%analysis_id=0
    session%last_attempt=0
    session%retained=0
    session%dropped=0
    status=ok
  end function

  integer(c_int) function engine_destroy(handle) bind(C,name='decoder_engine_destroy') result(status)
    type(c_ptr), value :: handle
    status=invalid
    if(.not.valid_handle(handle)) return
    status=busy
    if(session%running) return
    call reset_ft8_kernel(session%kernel)
    deallocate(session)
    host_handle=c_null_ptr
    status=ok
  end function

  subroutine request_to_params(request,valid_samples,params)
    type(attempt_request), intent(in) :: request
    integer, intent(in) :: valid_samples
    type(params_block), intent(out) :: params
    integer(c_int8_t) :: zeros(c_sizeof(params))
    zeros=0
    params=transfer(zeros,params)
    params%nmode=8
    params%ntr=15
    params%kin=valid_samples
    params%ndiskdat=request%source==1
    params%nagain=request%phase==3
    params%newdat=request%ft8%reuse_spectrum==0
    params%nzhsym=request%ft8%half_symbol_stage
    params%nutc=request%ft8%utc
    params%nQSOProgress=request%ft8%qso_progress
    params%nfqso=request%ft8%receive_frequency_hz
    params%nftx=request%ft8%transmit_frequency_hz
    params%nfa=request%ft8%search_low_hz
    params%nfb=request%ft8%search_high_hz
    params%ntol=request%ft8%tolerance_hz
    params%ndepth=request%ft8%depth
    params%napwid=request%ft8%ap_width_hz
    params%nexp_decode=request%ft8%contest
    params%ncandthin=request%ft8%candidate_thinning
    params%ndtcenter=request%ft8%time_center
    params%nft8cycles=request%ft8%cycles
    params%nranera=request%ft8%trials
    params%nlasttx=request%ft8%last_transmit
    params%ndelay=request%ft8%delay
    params%nmt=request%ft8%threads
    params%nft8rxfsens=request%ft8%receive_sensitivity
    params%nsecbandchanged=request%ft8%discard_leading_seconds
    params%yymmdd=request%ft8%date
    params%lft8apon=request%ft8%ap_enabled/=0
    params%lapcqonly=request%ft8%cq_only/=0
    params%b_even_seq=request%ft8%even_sequence/=0
    params%b_superfox=request%ft8%superfox/=0
    params%nagainfil=request%ft8%filtered_retry/=0
    params%nstophint=request%ft8%stop_hint/=0
    params%lmultift8=request%ft8%mtd/=0
    params%lft8lowth=request%ft8%low_threshold/=0
    params%lft8subpass=request%ft8%subtract_pass/=0
    params%ltxing=request%ft8%transmitting/=0
    params%lhideft8dupes=request%ft8%hide_duplicates/=0
    params%lhound=request%ft8%hound/=0
    params%lmycallstd=request%ft8%standard_mycall/=0
    params%lhiscallstd=request%ft8%standard_hiscall/=0
    params%lapmyc=request%ft8%ap_mycall/=0
    params%lmodechanged=request%ft8%mode_changed/=0
    params%lbandchanged=request%ft8%band_changed/=0
    params%lenabledxcsearch=request%ft8%dx_search/=0
    params%lwidedxcsearch=request%ft8%wide_dx_search/=0
    params%lmultinst=request%ft8%multiple_instances/=0
    params%lskiptx1=request%ft8%skip_first_message/=0
    params%emedelay=request%ft8%eme_delay_seconds
    params%mycall=request%ft8%mycall
    params%mybcall=request%ft8%my_base_call
    params%hiscall=request%ft8%hiscall
    params%hisbcall=request%ft8%his_base_call
    params%mygrid=request%ft8%mygrid
    params%hisgrid=request%ft8%hisgrid
  end subroutine

  subroutine engine_host_decode(id2,params,nfsample,completion,progress,input_id,analysis_id,attempt_no,valid_samples)
    integer(c_short), target, intent(in) :: id2(*)
    type(params_block), intent(in) :: params
    integer, intent(in) :: nfsample,progress,attempt_no,valid_samples
    integer(c_int64_t), intent(in) :: input_id,analysis_id
    type(decode_completion_result), intent(out) :: completion
    type(attempt_request) :: request
    type(audio_view) :: audio
    type(attempt_outcome) :: outcome
    type(engine_options) :: options
    integer(c_int) :: status
    character(len=12), allocatable :: calls(:)
    character(len=4), allocatable :: grids(:)
    options%abi_version=engine_abi
    completion=decode_completion_result(.true.,0,0,0)
    if(params%nmode==engine_mode_ft4) then
       ! The legacy host's low-signal gate includes its zero-padded 15-second window.
       if(sqrt(sum(real(id2(1:180000))**2)/180000.0)<0.5) return
    endif
    request%input_id=input_id
    request%mode=params%nmode
    request%analysis_id=analysis_id
    request%attempt_no=attempt_no
    if(.not.valid_handle(host_handle)) then
       status=engine_create(options,host_handle)
       if(status/=ok) then
          call report_host_rejection(status,request,'create')
          return
       endif
    endif
    if(input_id<=0.or.analysis_id<=0) then
       if(session%input_id==0.or.params%nutc/=fallback_utc.or.session%input_mode/=params%nmode.or. &
            ((params%nmode==engine_mode_ft4.or.params%nmode==engine_mode_jt9.or. &
            params%nmode==engine_mode_jt65).and..not.params%nagain).or. &
            (params%nzhsym==41.and..not.params%nagain)) then
          fallback_input=fallback_input+1
          fallback_analysis=fallback_analysis+1
       else if(params%nagain) then
          fallback_analysis=fallback_analysis+1
       endif
       request%input_id=max(1_c_int64_t,fallback_input)
       request%analysis_id=max(1_c_int64_t,fallback_analysis)
       request%attempt_no=session%last_attempt+1
       fallback_utc=params%nutc
    endif
    if(session%input_id/=0.and.(session%input_id/=request%input_id.or.session%input_mode/=request%mode)) then
       status=engine_release_input(host_handle,session%input_id)
       if(status/=ok) then
          call report_host_rejection(status,request,'release-input')
          return
       endif
    endif
    request%phase=2
    if(params%nmode==engine_mode_ft8.and.params%nzhsym<50) request%phase=1
    if(params%nagain) request%phase=3
    request%source=merge(1,0,params%ndiskdat)
    if(request%mode==engine_mode_ft4) then
       request%ft4%utc=params%nutc
       request%ft4%qso_progress=params%nQSOProgress
       request%ft4%receive_frequency_hz=params%nfqso
       request%ft4%search_low_hz=params%nfa
       request%ft4%search_high_hz=params%nfb
       request%ft4%depth=iand(params%ndepth,7)
       request%ft4%cq_only=merge(1,0,params%lapcqonly)
       request%ft4%contest=iand(params%nexp_decode,7)
       request%ft4%mycall=params%mycall
       request%ft4%hiscall=params%hiscall
    else if(request%mode==engine_mode_jt9) then
       request%jt9%utc=params%nutc
       request%jt9%receive_frequency_hz=params%nfqso
       request%jt9%search_low_hz=params%nfa
       request%jt9%search_high_hz=params%nfb
       request%jt9%tolerance_hz=params%ntol
       request%jt9%depth=iand(params%ndepth,7)
       request%jt9%submode=params%nsubmode
    else if(request%mode==engine_mode_jt65) then
       request%jt65%utc=params%nutc
       request%jt65%qso_progress=params%nQSOProgress
       request%jt65%receive_frequency_hz=params%nfqso
       request%jt65%search_low_hz=params%nfa
       request%jt65%search_high_hz=params%nfb
       request%jt65%tolerance_hz=params%ntol
       request%jt65%depth=iand(params%ndepth,7)
       request%jt65%submode=params%nsubmode
       request%jt65%min_sync=params%minsync
       request%jt65%passes=max(1,min(2,params%n2pass))
       request%jt65%trials=10**(params%nranera/2)
       if(mod(params%nranera,2)==1) request%jt65%trials=3*request%jt65%trials
       if(params%nranera==0) request%jt65%trials=0
       request%jt65%aggressiveness=params%naggressive
       request%jt65%single_decode=merge(1,0,iand(params%nexp_decode,32)/=0)
       request%jt65%vhf=merge(1,0,iand(params%nexp_decode,64)/=0)
       request%jt65%averaging=merge(1,0,iand(params%ndepth,16)/=0)
       request%jt65%auto_clear=merge(1,0,iand(params%ndepth,128)/=0)
       request%jt65%deep_search=merge(1,0,iand(params%ndepth,32)/=0)
       request%jt65%ap_enabled=merge(1,0,params%ljt65apon)
       request%jt65%mycall=params%mycall
       request%jt65%hiscall=params%hiscall
       request%jt65%hisgrid=params%hisgrid
       if(params%nclearave) call session%jt65%clear_averages()
       if(request%jt65%deep_search/=0) then
          call load_jt65_calls(calls,grids)
          call session%jt65%set_calls(calls,grids)
       endif
    else
       request%ft8%reuse_spectrum=merge(0,1,params%newdat)
       request%ft8%half_symbol_stage=params%nzhsym
       request%ft8%utc=params%nutc
       request%ft8%qso_progress=params%nQSOProgress
       request%ft8%receive_frequency_hz=params%nfqso
       request%ft8%transmit_frequency_hz=params%nftx
       request%ft8%search_low_hz=params%nfa
       request%ft8%search_high_hz=params%nfb
       request%ft8%tolerance_hz=params%ntol
       request%ft8%depth=params%ndepth
       request%ft8%ap_width_hz=params%napwid
       request%ft8%contest=params%nexp_decode
       request%ft8%candidate_thinning=params%ncandthin
       request%ft8%time_center=params%ndtcenter
       request%ft8%cycles=params%nft8cycles
       request%ft8%trials=params%nranera
       request%ft8%last_transmit=params%nlasttx
       request%ft8%delay=params%ndelay
       request%ft8%threads=params%nmt
       request%ft8%receive_sensitivity=params%nft8rxfsens
       request%ft8%discard_leading_seconds=params%nsecbandchanged
       request%ft8%date=params%yymmdd
       request%ft8%ap_enabled=merge(1,0,params%lft8apon)
       request%ft8%cq_only=merge(1,0,params%lapcqonly)
       request%ft8%even_sequence=merge(1,0,params%b_even_seq)
       request%ft8%superfox=merge(1,0,params%b_superfox)
       request%ft8%filtered_retry=merge(1,0,params%nagainfil)
       request%ft8%stop_hint=merge(1,0,params%nstophint)
       request%ft8%mtd=merge(1,0,params%lmultift8)
       request%ft8%low_threshold=merge(1,0,params%lft8lowth)
       request%ft8%subtract_pass=merge(1,0,params%lft8subpass)
       request%ft8%transmitting=merge(1,0,params%ltxing)
       request%ft8%hide_duplicates=merge(1,0,params%lhideft8dupes)
       request%ft8%hound=merge(1,0,params%lhound)
       request%ft8%standard_mycall=merge(1,0,params%lmycallstd)
       request%ft8%standard_hiscall=merge(1,0,params%lhiscallstd)
       request%ft8%ap_mycall=merge(1,0,params%lapmyc)
       request%ft8%mode_changed=merge(1,0,params%lmodechanged)
       request%ft8%band_changed=merge(1,0,params%lbandchanged)
       request%ft8%dx_search=merge(1,0,params%lenabledxcsearch)
       request%ft8%wide_dx_search=merge(1,0,params%lwidedxcsearch)
       request%ft8%multiple_instances=merge(1,0,params%lmultinst)
       request%ft8%skip_first_message=merge(1,0,params%lskiptx1)
       request%ft8%eme_delay_seconds=params%emedelay
       request%ft8%mycall=params%mycall
       request%ft8%my_base_call=params%mybcall
       request%ft8%hiscall=params%hiscall
       request%ft8%his_base_call=params%hisbcall
       request%ft8%mygrid=params%mygrid
       request%ft8%hisgrid=params%hisgrid
    endif
    audio%samples=c_loc(id2(1))
    audio%sample_count=min(analysis_extent(request%mode),valid_samples)
    if(valid_samples<=0.and.input_id<=0) then
       audio%sample_count=analysis_extent(request%mode)
       if(request%mode==engine_mode_jt9.or.request%mode==engine_mode_jt65) audio%sample_count=624000
    endif
    if(request%mode==engine_mode_ft8) then
       if(params%lmultift8.and..not.(iand(params%nexp_decode,7)==7.and. &
            params%b_superfox.and.params%b_even_seq)) &
            audio%sample_count=min(audio%sample_count,params%nzhsym*3456)
    endif
    audio%sample_rate_hz=nfsample
    status=decode_attempt(host_handle,request,audio,c_null_funptr,c_null_ptr,outcome,.true.,progress)
    if(status==ok) then
       completion=session%completion
    else
       call report_host_rejection(status,request,'decode')
    endif
  end subroutine

  subroutine report_host_rejection(status,request,operation)
    integer(c_int), intent(in) :: status
    type(attempt_request), intent(in) :: request
    character(len=*), intent(in) :: operation
    character(len=12) :: status_name
    select case(status)
    case(invalid)
       status_name='invalid'
    case(busy)
       status_name='busy'
    case(unsupported)
       status_name='unsupported'
    case default
       write(status_name,'(i0)') status
    end select
    write(*,'(a,a,a,a,4(a,i0))') '<DecodeRejected> status=',trim(status_name), &
         ' operation=',operation,' mode=',request%mode,' input=',request%input_id, &
         ' analysis=',request%analysis_id,' attempt=',request%attempt_no
    flush(6)
  end subroutine report_host_rejection
end module decoder_engine

subroutine run_decoder_engine(id2,params,nfsample,completion,progress_generation, &
     input_id,analysis_id,attempt_no,valid_samples)
  use, intrinsic :: iso_c_binding, only: c_short,c_int,c_int64_t
  use decoder_engine, only: engine_host_decode
  use ft8_engine_kernel, only: params_block
  use decode_completion_module, only: decode_completion_result
  implicit none
  integer(c_short), target, intent(in) :: id2(*)
  type(params_block), intent(in) :: params
  integer(c_int), intent(in) :: nfsample,progress_generation,attempt_no,valid_samples
  integer(c_int64_t), intent(in) :: input_id,analysis_id
  type(decode_completion_result), intent(out) :: completion
  call engine_host_decode(id2,params,nfsample,completion,progress_generation,input_id,analysis_id,attempt_no,valid_samples)
end subroutine
