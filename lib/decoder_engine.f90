module decoder_engine
  use, intrinsic :: iso_c_binding
  use decoder_engine_types
  use packjt77, only: pack77_state
  use ft8_engine_kernel, only: ft8_kernel_state,params_block,run_ft8_kernel,reset_ft8_kernel,release_ft8_input
  use decoder_callbacks, only: decoder_callback_context,counting_ft4_decoder,ft4_decoded
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
  type, bind(C) :: attempt_request
     integer(c_int64_t) :: input_id=0,analysis_id=0
     integer(c_int) :: attempt_no=0,mode=8,phase=2,source=0
     type(ft8_options) :: ft8
     type(ft4_options) :: ft4
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
     type(attempt_request) :: request
     type(engine_observation) :: evidence(evidence_capacity)
     integer(c_short) :: audio(180000)=0
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
    call reset_ft8_kernel(session%kernel)
    handle=c_loc(token)
    status=ok
  end function

  integer(c_int) function engine_get_capabilities(handle,caps) &
       bind(C,name='decoder_engine_get_capabilities') result(status)
    type(c_ptr), value :: handle
    type(engine_capabilities), intent(out) :: caps
    caps=engine_capabilities(engine_abi,ior(engine_support_ft8,engine_support_ft4),0,0,evidence_capacity)
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
    type(params_block) :: params
    type(decoder_callback_context) :: context
    outcome=attempt_outcome()
    status=invalid
    if(.not.valid_handle(handle)) go to 900
    status=busy
    if(session%running) go to 900
    status=unsupported
    if(request%mode/=engine_mode_ft8.and.request%mode/=engine_mode_ft4) go to 900
    if(audio%sample_rate_hz/=12000) go to 900
    status=invalid
    if(request%input_id<=0.or.request%analysis_id<=0.or.request%attempt_no<=0) go to 900
    if(request%phase<1.or.request%phase>3.or.request%source<0.or.request%source>1) go to 900
    if(audio%sample_count<1.or.audio%sample_count>180000) go to 900
    if(.not.c_associated(audio%samples)) go to 900
    if(request%mode==engine_mode_ft4) then
       if(audio%sample_count>72576.or.request%phase==1) go to 900
       if(request%ft4%search_low_hz<0.or.request%ft4%search_high_hz>6000.or. &
            request%ft4%search_low_hz>request%ft4%search_high_hz) go to 900
       if(request%ft4%depth<1.or.request%ft4%depth>3) go to 900
       if(request%ft4%qso_progress<0.or.request%ft4%qso_progress>5) go to 900
       if(request%ft4%contest<0.or.request%ft4%contest>7) go to 900
       if(request%ft4%cq_only<0.or.request%ft4%cq_only>1) go to 900
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
    session%audio=0
    call c_f_pointer(audio%samples,samples,[audio%sample_count])
    session%audio(1:audio%sample_count)=samples
    context%sink=>collect_observation
    context%superfox_sink=>collect_superfox
    context%sink_user=handle
    context%render_legacy=render
    if(request%mode==engine_mode_ft4) then
       call run_ft4_attempt(request%ft4,request%phase,context,progress)
    else
       call request_to_params(request,audio%sample_count,params)
       call run_ft8_kernel(session%kernel,session%knowledge,session%audio,params,session%completion,progress,context)
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

  subroutine run_ft4_attempt(options,phase,callback_context,progress)
    type(ft4_options), intent(in) :: options
    integer, intent(in) :: phase,progress
    type(decoder_callback_context), intent(in) :: callback_context
    type(decoder_callback_context) :: context
    character(len=12) :: mycall,hiscall
    integer :: tries

    context=callback_context
    context%nutc=options%utc
    context%nfqso=options%receive_frequency_hz
    context%ncontest=options%contest
    context%ios13=-1
    if(context%render_legacy) then
       do tries=1,4
          if(phase==3) then
             open(13,file=trim(temp_dir)//'/decoded.txt',status='unknown',position='append',iostat=context%ios13)
          else
             open(13,file=trim(temp_dir)//'/decoded.txt',status='unknown',iostat=context%ios13)
          endif
          if(context%ios13==0) exit
          if(tries<4) call sleep_msec(10)
       enddo
    endif
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
    session%knowledge=pack77_state()
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
    options%abi_version=engine_abi
    completion=decode_completion_result(.true.,0,0,0)
    if(params%nmode==engine_mode_ft4) then
       ! The legacy host's low-signal gate includes its zero-padded 15-second window.
       if(sqrt(sum(real(id2(1:180000))**2)/180000.0)<0.5) return
    endif
    if(.not.valid_handle(host_handle)) then
       status=engine_create(options,host_handle)
       if(status/=ok) return
    endif
    request%input_id=input_id
    request%mode=params%nmode
    request%analysis_id=analysis_id
    request%attempt_no=attempt_no
    if(input_id<=0.or.analysis_id<=0) then
       if(session%input_id==0.or.params%nutc/=fallback_utc.or.session%input_mode/=params%nmode.or. &
            (params%nmode==engine_mode_ft4.and..not.params%nagain).or. &
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
    if(session%input_id/=0.and.(session%input_id/=request%input_id.or.session%input_mode/=request%mode)) &
         status=engine_release_input(host_handle,session%input_id)
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
    audio%sample_count=min(180000,valid_samples)
    if(valid_samples<=0.and.input_id<=0) audio%sample_count=180000
    if(request%mode==engine_mode_ft4) then
       audio%sample_count=min(audio%sample_count,72576)
    else
       if(params%lmultift8.and..not.(iand(params%nexp_decode,7)==7.and. &
            params%b_superfox.and.params%b_even_seq)) &
            audio%sample_count=min(audio%sample_count,params%nzhsym*3456)
    endif
    audio%sample_rate_hz=nfsample
    status=decode_attempt(host_handle,request,audio,c_null_funptr,c_null_ptr,outcome,.true.,progress)
    if(status==ok) completion=session%completion
  end subroutine
end module decoder_engine

subroutine run_decoder_engine(ss,id2,params,nfsample,completion,progress_generation, &
     input_id,analysis_id,attempt_no,valid_samples)
  use, intrinsic :: iso_c_binding, only: c_short,c_int,c_int64_t,c_float
  use decoder_engine, only: engine_host_decode
  use ft8_engine_kernel, only: params_block
  use decode_completion_module, only: decode_completion_result
  implicit none
  real(c_float), intent(in) :: ss(*)
  integer(c_short), target, intent(in) :: id2(*)
  type(params_block), intent(in) :: params
  integer(c_int), intent(in) :: nfsample,progress_generation,attempt_no,valid_samples
  integer(c_int64_t), intent(in) :: input_id,analysis_id
  type(decode_completion_result), intent(out) :: completion
  call engine_host_decode(id2,params,nfsample,completion,progress_generation,input_id,analysis_id,attempt_no,valid_samples)
end subroutine
