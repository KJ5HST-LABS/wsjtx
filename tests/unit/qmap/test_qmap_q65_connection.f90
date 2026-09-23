program test_qmap_q65_connection
  use iso_fortran_env, only: real64
  use q65_test_fixture, only: q65_tones, q65_nsymbols
  use qmap_candidates_mod, only: candidate, getcand2
  use qmap_decode_ipc, only: ndecodes, result
  use q65_decode, only: msg0, nfreq0, nsnr0, xdt0
  use timer_impl, only: init_timer, fini_timer
  implicit none

  integer, parameter :: nfft=32768, nsmax=5760000, sample_rate=96000
  integer, parameter :: max_candidates=50
  real, parameter :: sync_hz=16817.0*sample_rate/nfft
  real :: dd(2,nsmax),ss(400,nfft),savg(nfft)
  real(real64) :: fcenter
  integer :: nutc
  integer :: junk(42)
  common/datcom/dd,ss,savg,fcenter,nutc,junk
  real :: display(nfft),savg_fresh(nfft),phase,omega,amplitude,frequency
  logical(kind=1) :: also30,click,lstrong(0:1023)
  type(candidate) :: cand(max_candidates)
  integer :: seed_size,symbol,i,k,nb,nbslider,nkh,ihsym,nzap,ncand,selected,idec
  integer, allocatable :: seed(:)
  real :: pxdb,slimit
  character(len=20) :: datetime

  call random_seed(size=seed_size)
  allocate(seed(seed_size))
  seed=104729
  call random_seed(put=seed)
  call random_number(dd)
  dd=2.0*(dd-0.5)
  ss=0.0
  savg=0.0
  fcenter=144.125_real64
  nutc=100

  phase=0.0
  amplitude=160.0
  do symbol=1,q65_nsymbols
     frequency=sync_hz+real(q65_tones(symbol))*12000.0/7200.0
     omega=2.0*acos(-1.0)*frequency/real(sample_rate)
     do i=1,57600
        k=sample_rate+(symbol-1)*57600+i
        phase=phase+omega
        if(phase > 2.0*acos(-1.0)) phase=phase-2.0*acos(-1.0)
        dd(1,k)=dd(1,k)+amplitude*cos(phase)
        dd(2,k)=dd(2,k)-amplitude*sin(phase)
     enddo
  enddo

  call init_timer()
  nb=0
  nbslider=40
  slimit=0.0
  ihsym=0
  do i=1,390
     k=28800+(i-1)*14400
     call symspec(k,1,nb,nbslider,sample_rate,pxdb,display,nkh,ihsym,nzap,slimit,lstrong)
  enddo
  call require(ihsym==390, 'complete QMAP symbol spectra')

  savg_fresh=savg
  also30=.false.
  call getcand2(ss,savg_fresh,1,1,ihsym,0,0,15,sync_hz/1000.0,also30,cand,ncand)
  selected=0
  do i=1,ncand
     if(cand(i)%ntrperiod/=60 .or. cand(i)%iseq/=0) cycle
     if(abs(1000.0*cand(i)%f-sync_hz)>10.0) cycle
     selected=i
     exit
  enddo
  call require(selected>0, 'find generated Q65 sync candidate')

  call fftbig(dd,nsmax)
  ndecodes=0
  open(unit=12,status='scratch')
  datetime='2026-09-23 12:00:00 '
  click=.false.
  idec=-1
  call q65b(nutc,0,fcenter,0,sample_rate,125,0,100,60,0, &
       'N0CALL      ','            ','      ',1,cand(selected)%f,1.270,125, &
       1,0,click,0,0,3,datetime,0,0,ihsym,idec)
  call require(nsnr0 > -99, 'decode generated Q65 signal')
  call require(trim(msg0)=='K1ABC W9XYZ FN42', 'recover generated Q65 message')
  call require(abs(nfreq0-1000)<20, 'QMAP decoder reports centered audio frequency')
  call require(abs(xdt0)<0.5, 'QMAP decoder reports generated timing')
  call require(ndecodes==1 .and. index(result(1),'K1ABC W9XYZ FN42')>0, &
       'QMAP publishes decoded message')
  call fini_timer()
  print '(a)', 'QMAP generated Q65 connection passed.'

contains

  subroutine require(condition,description)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: description
    if (.not. condition) then
       print '(a)', 'FAIL: '//description
       error stop 1
    endif
  end subroutine require
end program test_qmap_q65_connection
