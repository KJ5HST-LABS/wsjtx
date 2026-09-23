program test_qmap_q65_handoff
  use iso_fortran_env, only: int16, real64
  use cacb_mod, only: ca, init_cacb
  use qmap_q65_samples_mod, only: build_q65_samples
  implicit none

  integer, parameter :: nfft2=336000, nfft1=5376000, k0=2600000
  real, parameter :: df=96000.0/nfft1
  integer(int16), allocatable :: desired(:), wave(:)
  complex, allocatable :: spectrum(:)
  integer :: i,j
  real(real64) :: t

  allocate(desired(720000),wave(720000),spectrum(0:nfft2))
  desired=0
  do i=1,27*12000
     t=real(i-1,real64)/12000.0_real64
     desired(i)=int(nint(100.0_real64*sin(2.0_real64*acos(-1.0_real64)*1000.0_real64*t)),int16)
  enddo
  do i=30*12000+1,55*12000
     t=real(i-1,real64)/12000.0_real64
     desired(i)=int(nint(100.0_real64*sin(2.0_real64*acos(-1.0_real64)*1200.0_real64*t)),int16)
  enddo

  do i=0,nfft2-1
     j=nfft2-1-i
     spectrum(j)=cmplx(real(desired(2*i+2)),real(desired(2*i+1)))
  enddo
  spectrum(nfft2)=0.
  call four2a(spectrum,2*nfft2,1,-1,0)
  call init_cacb(nfft1)
  ca=0.
  ca(k0:k0+nfft2-1)=0.5*spectrum(0:nfft2-1)

  call build_q65_samples(k0,nfft2,df,0,wave)
  call require(tone_at(wave,1,12,6), 'first half contains the 1000 Hz signal')
  call require(mean_power(wave,27*12000+1,30*12000) < 1.0_real64, 'first-half guard is quiet')
  call require(all(wave(2*nfft2+1:)==0), '56-second extraction has a zero tail')
  call require(maxval(abs(int(wave))) < 1000, 'samples do not clip')

  call build_q65_samples(k0,nfft2,df,1,wave)
  call require(tone_at(wave,1,10,5), 'second-half selection contains the 1200 Hz signal')
  call require(mean_power(wave,25*12000+1,30*12000) < 1.0_real64, 'second-half tail is quiet')
  call require(maxval(abs(int(wave))) < 1000, 'selected samples do not clip')

  print '(a)', 'QMAP Q65 sample handoff contracts passed.'

contains

  real(real64) function mean_power(samples,first,last)
    integer(int16), intent(in) :: samples(:)
    integer, intent(in) :: first,last
    integer :: index
    mean_power=0.0_real64
    do index=first,last
       mean_power=mean_power+real(samples(index),real64)**2
    enddo
    mean_power=mean_power/real(last-first+1,real64)
  end function mean_power

  logical function tone_at(samples,first,period,half_period)
    integer(int16), intent(in) :: samples(:)
    integer, intent(in) :: first,period,half_period
    integer :: index
    real(real64) :: same,opposite,energy
    same=0.0_real64
    opposite=0.0_real64
    energy=0.0_real64
    do index=first,first+12000-1
       same=same+real(samples(index),real64)*real(samples(index+period),real64)
       opposite=opposite+real(samples(index),real64)*real(samples(index+half_period),real64)
       energy=energy+real(samples(index),real64)**2
    enddo
    tone_at=energy > 1000000.0_real64 .and. same/energy > 0.98_real64 .and. &
         opposite/energy < -0.98_real64
  end function tone_at

  subroutine require(condition,description)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: description
    if (.not. condition) then
       print '(a)', 'FAIL: '//description
       error stop 1
    endif
  end subroutine require
end program test_qmap_q65_handoff
