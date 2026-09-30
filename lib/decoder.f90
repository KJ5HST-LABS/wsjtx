subroutine multimode_decoder_core(ss,id2,params,nfsample,completion,progress_generation)

!$ use omp_lib
  use prog_args
  use timer_module, only: timer
  use jt4_decode
  use jt65_decode
  use jt9_decode
  use fst4_decode
  use q65_decode
  use decoder_callbacks, only: decoder_callback_context,                     &
       counting_jt4_decoder, counting_jt65_decoder, counting_jt9_decoder,    &
       counting_fst4_decoder,counting_q65_decoder,                           &
       fst4_decoded, q65_decoded, jt4_decoded,                                &
       jt4_average, jt65_decoded, jt9_decoded
  use streaming_emit, only: streaming_emit_enabled,                       &
       streaming_emit_decode
  use decode_completion_module, only: decode_completion_result,          &
       reset_decode_completion, set_decode_completion, write_decode_progress


  include 'jt9com.f90'

  interface
     subroutine wsjt_tsan_acquire_decoder_section_primary() bind(C)
     end subroutine wsjt_tsan_acquire_decoder_section_primary
     subroutine wsjt_tsan_release_decoder_section_primary() bind(C)
     end subroutine wsjt_tsan_release_decoder_section_primary
     subroutine wsjt_tsan_acquire_decoder_section_secondary() bind(C)
     end subroutine wsjt_tsan_acquire_decoder_section_secondary
     subroutine wsjt_tsan_release_decoder_section_secondary() bind(C)
     end subroutine wsjt_tsan_release_decoder_section_secondary
  end interface

  integer, intent(in) :: progress_generation
  integer :: active_progress_generation
  type(params_block) :: params
  type(decode_completion_result), intent(out) :: completion
  external :: run_decoder_engine
  type(decoder_callback_context) :: callback_context
  real ss(184,NSMAX)
  logical baddata,newdat65,newdat9,single_decode,bVHF,q65_pileup,bad0,ex
  logical lprinthash22
  integer*2 id2(NTMAX*12000)
  integer nqf(20)
  real*4 dd(NTMAX*12000)
  character(len=20) :: datetime
  character(len=12) :: mycall, hiscall
  character(len=6) :: mygrid, hisgrid
  character*60 line
  data ntr0/-1/
  save
  type(counting_jt4_decoder) :: my_jt4
  type(counting_jt65_decoder) :: my_jt65
  type(counting_jt9_decoder) :: my_jt9
  type(counting_fst4_decoder) :: my_fst4
  type(counting_q65_decoder) :: my_q65  

  if(params%nmode.eq.8.or.params%nmode.eq.5) then
     call run_decoder_engine(ss,id2,params,nfsample,completion,progress_generation, &
          0_c_int64_t,0_c_int64_t,0_c_int,merge(params%kin,0_c_int,params%nmode==5))
     return
  endif

  call reset_decode_completion(completion)
  active_progress_generation=progress_generation

  my_jt4%decoded = 0
  my_jt65%decoded = 0
  my_jt9%decoded = 0
  my_fst4%decoded = 0
  my_q65%decoded = 0
  nsynced=0
  navg0=0

  if(.not.params%newdat .and. params%ntr.gt.ntr0) go to 800
  ntr0=params%ntr
  rms=sqrt(dot_product(float(id2(1:180000)),float(id2(1:180000)))/180000.0)
  if(rms.lt.0.5) go to 800

! Cast C character arrays to Fortran character strings
  datetime=transfer(params%datetime, datetime)
  mycall=transfer(params%mycall,mycall)
  hiscall=transfer(params%hiscall,hiscall)
  mygrid=transfer(params%mygrid,mygrid)
  hisgrid=transfer(params%hisgrid,hisgrid)

! For testing only: return Rx messages stored in a file as decodes
  inquire(file='rx_messages.txt',exist=ex)
  if(ex) then
     if(params%nzhsym.eq.41) then
        open(39,file='rx_messages.txt',status='old')
        do i=1,9999
           read(39,'(a60)',end=5) line
           if(line(1:1).eq.' ' .or. line(1:1).eq.'-') go to 800
           write(*,'(a)') trim(line)
        enddo
5       close(39)
     endif
     go to 800
  endif

  ncontest=iand(params%nexp_decode,7)
  single_decode=iand(params%nexp_decode,32).ne.0
  bVHF=iand(params%nexp_decode,64).ne.0
  q65_pileup=iand(params%nexp_decode,128).ne.0  ! bit 7 is reserved for Q65 Pileup
  if(mod(params%nranera,2).eq.0) ntrials=10**(params%nranera/2)
  if(mod(params%nranera,2).eq.1) ntrials=3*10**(params%nranera/2)
  if(params%nranera.eq.0) ntrials=0

  nfail=0
10 if (params%nagain) then
     open(13,file=trim(temp_dir)//'/decoded.txt',status='unknown',            &
          position='append',iostat=ios13)
  else
     open(13,file=trim(temp_dir)//'/decoded.txt',status='unknown',iostat=ios13)
  endif
  if(ios13.ne.0) then
     nfail=nfail+1
     if(nfail.le.3) then
        call sleep_msec(10)
        go to 10
     endif
  endif

  callback_context%nutc = params%nutc
  callback_context%nfqso = params%nfqso
  callback_context%ncontest = ncontest
  callback_context%ios13 = ios13
  callback_context%bVHF = bVHF
  callback_context%b_superfox = params%b_superfox
  callback_context%mycall = mycall
  my_jt4%context = callback_context
  my_jt65%context = callback_context
  my_jt9%context = callback_context
  my_fst4%context = callback_context
  my_q65%context = callback_context

  if(params%nmode.eq.66) then        !NB: JT65 = 65, Q65 = 66.
     ! We're in Q65 mode
     open(17,file=trim(temp_dir)//'/red.dat',status='unknown')
     open(14,file=trim(temp_dir)//'/avemsg.txt',status='unknown')
     call timer('dec_q65 ',0)
     nqd=1
     call my_q65%decode(q65_decoded,id2,nqd,params%nutc,params%ntr,      &
          params%nsubmode,params%nfqso,params%ntol,params%ndepth,        &
          params%nfa,params%nfb,logical(params%nclearave),               &
          single_decode,logical(params%nagain),params%max_drift,         &
          logical(params%newdat),params%emedelay,mycall,hiscall,hisgrid, &
          params%nQSOProgress,ncontest,q65_pileup,logical(params%lapcqonly),  &
          navg0,nqf)
     params%nclearave=.false.

     if(.not.params%nagain) then
                ! Go through identified candidates again, treating each as if it had been
                ! double-clicked on the waterfall.
        do k=1,20
           if(nqf(k).eq.0) exit
           if(params%nagain .and. abs(nqf(k)-params%nfqso).gt.params%ntol) cycle
           nqd=1
           navg0=0
           ntol=5
           call my_q65%decode(q65_decoded,id2,nqd,params%nutc,params%ntr,    &
                params%nsubmode,nqf(k),ntol,params%ndepth,                   &
                params%nfa,params%nfb,logical(params%nclearave),             &
                .true.,.true.,params%max_drift,                              &
                .false.,params%emedelay,mycall,hiscall,hisgrid,              &
                params%nQSOProgress,ncontest,q65_pileup,                       &
                logical(params%lapcqonly),navg0,nqf)
        enddo
     endif

     call timer('dec_q65 ',1)
     close(17)
     go to 800
  endif

  if(params%nmode.eq.240) then
     ! We're in FST4 mode
     ndepth=iand(params%ndepth,3)
     iwspr=0
     lprinthash22=.false.
     params%nsubmode=0
     call timer('dec_fst4',0)
     call my_fst4%decode(fst4_decoded,id2,params%nutc,                &
          params%nQSOProgress,params%nfa,params%nfb,                  &
          params%nfqso,ndepth,params%ntr,params%nexp_decode,          &
          params%ntol,params%emedelay,logical(params%nagain),         &
          logical(params%lapcqonly),mycall,hiscall,iwspr,lprinthash22)
     call timer('dec_fst4',1)
     go to 800
  endif

  if(params%nmode.eq.241 .or. params%nmode.eq.242) then
     ! We're in FST4W mode
     ndepth=iand(params%ndepth,3)
     iwspr=1
     lprinthash22=.false.
     if(params%nmode.eq.242) lprinthash22=.true. 
     call timer('dec_fst4',0)
     call my_fst4%decode(fst4_decoded,id2,params%nutc,                &
          params%nQSOProgress,params%nfa,params%nfb,                  &
          params%nfqso,ndepth,params%ntr,params%nexp_decode,          &
          params%ntol,params%emedelay,logical(params%nagain),         &
          logical(params%lapcqonly),mycall,hiscall,iwspr,lprinthash22)
     call timer('dec_fst4',1)
     go to 800
  endif

  ! Zap data at start that might come from T/R switching transient?
  nadd=100
  k=0
  bad0=.false.
  do i=1,240
     sq=0.
     do n=1,nadd
        k=k+1
        sq=sq + float(id2(k))**2
     enddo
     rms=sqrt(sq/nadd)
     if(rms.gt.10000.0) then
        bad0=.true.
        kbad=k
        rmsbad=rms
     endif
  enddo
  if(bad0) then
     nz=min(NTMAX*12000,kbad+100)
              !     id2(1:nz)=0                ! temporarily disabled as it can breaak the JT9 decoder, maybe others
  endif

  if(params%nmode.eq.4 .or. params%nmode.eq.65) open(14,file=trim(temp_dir)// &
       '/avemsg.txt',status='unknown')

  if(params%nmode.eq.4) then
     jz=52*nfsample
     if(params%newdat) then
        if(nfsample.eq.12000) call wav11(id2,jz,dd)
        if(nfsample.eq.11025) dd(1:jz)=id2(1:jz)
     else
        jz=52*11025
     endif
     call my_jt4%decode(jt4_decoded,dd,jz,params%nutc,params%nfqso,         &
          params%ntol,params%emedelay,params%dttol,logical(params%nagain),  &
          params%ndepth,logical(params%nclearave),params%minsync,           &
          params%minw,params%nsubmode,mycall,hiscall,         &
          hisgrid,params%nlist,params%listutc,jt4_average)
     go to 800
  endif

  npts65=52*12000
  if(baddata(id2,npts65)) then
     nsynced=0
     ndecoded=0
     go to 800
  endif
  
  ntol65=params%ntol              !### is this OK? ###
  newdat65=params%newdat
  newdat9=params%newdat

!$ call omp_set_dynamic(.true.)

  call wsjt_tsan_release_decoder_section_primary()
  call wsjt_tsan_release_decoder_section_secondary()
!$omp parallel sections num_threads(2) shared(ndecoded) if(.true.) !iif() needed on Mac

!$omp section
  call wsjt_tsan_acquire_decoder_section_primary()
  if(params%nmode.eq.65) then                       ! We're in JT65 mode     
     if(newdat65) dd(1:npts65)=id2(1:npts65)
     nf1=params%nfa
     nf2=params%nfb
     call timer('jt65a   ',0)
     call my_jt65%decode(jt65_decoded,dd,npts65,newdat65,params%nutc,      &
          nf1,nf2,params%nfqso,ntol65,params%nsubmode,params%minsync,      &
          logical(params%nagain),params%n2pass,logical(params%nrobust),    &
          ntrials,params%naggressive,params%ndepth,params%emedelay,        &
          logical(params%nclearave),mycall,hiscall,                        &
          hisgrid,params%nexp_decode,params%nQSOProgress,                  &
          logical(params%ljt65apon))
     call timer('jt65a   ',1)

  else if(params%nmode.eq.9 .or. (params%nmode.eq.(65+9) .and.             &
       params%ntxmode.eq.9)) then
              ! We're in JT9 mode, or should do JT9 first
     call timer('decjt9  ',0)
     call my_jt9%decode(jt9_decoded,ss,id2,params%nfqso,                   &
          newdat9,params%npts8,params%nfa,params%nfsplit,params%nfb,       &
          params%ntol,params%nzhsym,logical(params%nagain),params%ndepth,  &
          params%nmode,params%nsubmode,params%nexp_decode)
     call timer('decjt9  ',1)
  endif
  call wsjt_tsan_release_decoder_section_primary()

!$omp section
  call wsjt_tsan_acquire_decoder_section_secondary()
  if(params%nmode.eq.(65+9)) then       !Do the other mode (we're in dual mode)
     if (params%ntxmode.eq.9) then
        if(newdat65) dd(1:npts65)=id2(1:npts65)
        nf1=params%nfa
        nf2=params%nfb
        call timer('jt65a   ',0)
        call my_jt65%decode(jt65_decoded,dd,npts65,newdat65,params%nutc,   &
             nf1,nf2,params%nfqso,ntol65,params%nsubmode,params%minsync,   &
             logical(params%nagain),params%n2pass,logical(params%nrobust), &
             ntrials,params%naggressive,params%ndepth,params%emedelay,     &
             logical(params%nclearave),mycall,hiscall,       &
             hisgrid,params%nexp_decode,params%nQSOProgress,        &
             logical(params%ljt65apon))
        call timer('jt65a   ',1)
     else
        call timer('decjt9  ',0)
        call my_jt9%decode(jt9_decoded,ss,id2,params%nfqso,                &
             newdat9,params%npts8,params%nfa,params%nfsplit,params%nfb,    &
             params%ntol,params%nzhsym,logical(params%nagain),             &
             params%ndepth,params%nmode,params%nsubmode,params%nexp_decode)
        call timer('decjt9  ',1)
     end if
  endif
  call wsjt_tsan_release_decoder_section_secondary()

!$omp end parallel sections
  call wsjt_tsan_acquire_decoder_section_primary()
  call wsjt_tsan_acquire_decoder_section_secondary()


! JT65 is not yet producing info for nsynced, ndecoded.
800 ndecoded = my_jt4%decoded + my_jt65%decoded + my_jt9%decoded +       &
         my_fst4%decoded + my_q65%decoded
  call set_decode_completion(completion,nsynced,ndecoded,navg0)
  call write_decode_progress(active_progress_generation)
  close(13)
  if(params%nmode.eq.4 .or. params%nmode.eq.65 .or. params%nmode.eq.66) close(14)
  return
end subroutine multimode_decoder_core

subroutine multimode_decoder(ss,id2,params,nfsample)
  use prog_args, only: lquiet
  use streaming_emit, only: streaming_emit_enabled,                       &
       streaming_emit_decode_finished
  use decode_completion_module, only: decode_completion_result,          &
       write_decode_completion

  include 'jt9com.f90'

  real ss(184,NSMAX)
  integer*2 id2(NTMAX*12000)
  type(params_block) :: params
  type(decode_completion_result) :: completion

  call multimode_decoder_core(ss,id2,params,nfsample,completion,0)
  if (.not. completion%available) return

  if (streaming_emit_enabled()) then
     call streaming_emit_decode_finished(params%nutc)
  else if (.not. lquiet) then
     call write_decode_completion(completion)
  end if
  call flush(6)
end subroutine multimode_decoder
