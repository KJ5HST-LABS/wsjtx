program test_map65_q65_handoff
  use iso_fortran_env, only: int16, real64
  use cacb_mod, only: ca, cb, init_cacb
  use q65b_mod, only: build_q65_samples
  implicit none

  integer, parameter :: nfft2 = 336000, nfft1 = 5376000
  integer, parameter :: k_auto = 2600000, k_manual = 2600100
  real, parameter :: df = 96000.0/nfft1
  integer(int16), allocatable :: wave(:), reference(:)
  real(real64) :: reference_power, power

  allocate(wave(720000), reference(720000))
  call init_cacb(nfft1)
  ca = 0.
  cb = cmplx(1000000., -1000000.)
  ca(k_auto+nint(1000.0/df)) = cmplx(10000000., 0.)

  call build_q65_samples(k_auto,nfft2,df,.false.,0,0.0,reference)
  reference_power = mean_power(reference)
  call require(reference_power > 100.0_real64, 'moderate X-only level')
  call require(maxval(abs(int(reference))) < 1000, 'X-only samples do not clip')
  call require(all(reference(2*nfft2+1:) == 0), '56-second samples have a zero tail')
  call require(tone_at_1000(reference), 'automatic center produces 1000 Hz audio')

  cb = cmplx(-2000000., 3000000.)
  call build_q65_samples(k_auto,nfft2,df,.false.,180,45.0,wave)
  call require(all(wave == reference), 'single-polarization mode ignores Y')

  cb = ca
  call build_q65_samples(k_auto,nfft2,df,.true.,0,45.0,wave)
  power = mean_power(wave)
  call require(abs(power/reference_power-2.0_real64) < 0.08_real64, 'equal X and Y combine coherently')

  cb = -ca
  call build_q65_samples(k_auto,nfft2,df,.true.,0,45.0,wave)
  call require(mean_power(wave) < 1.0_real64, 'opposite-phase Y cancels without correction')
  call build_q65_samples(k_auto,nfft2,df,.true.,180,45.0,wave)
  power = mean_power(wave)
  call require(abs(power/reference_power-2.0_real64) < 0.08_real64, 'phase correction restores opposite-phase Y')

  ca = 0.
  ca(k_manual+nint(1000.0/df)) = cmplx(10000000., 0.)
  call build_q65_samples(k_manual,nfft2,df,.false.,0,0.0,wave)
  call require(tone_at_1000(wave), 'manual center produces 1000 Hz audio')
  call require(abs(mean_power(wave)/reference_power-1.0_real64) < 0.02_real64, &
       'manual center preserves sample level')

  print '(a)', 'MAP65 Q65 sample handoff contracts passed.'

contains

  real(real64) function mean_power(samples)
    integer(int16), intent(in) :: samples(:)
    integer :: i
    mean_power = 0.0_real64
    do i=1,2*nfft2
       mean_power = mean_power + real(samples(i),real64)**2
    enddo
    mean_power = mean_power/real(2*nfft2,real64)
  end function mean_power

  logical function tone_at_1000(samples)
    integer(int16), intent(in) :: samples(:)
    integer :: i
    real(real64) :: same, opposite, energy
    same = 0.0_real64
    opposite = 0.0_real64
    energy = 0.0_real64
    do i=1,12000
       same = same + real(samples(i),real64)*real(samples(i+12),real64)
       opposite = opposite + real(samples(i),real64)*real(samples(i+6),real64)
       energy = energy + real(samples(i),real64)**2
    enddo
    tone_at_1000 = same/energy > 0.98_real64 .and. opposite/energy < -0.98_real64
  end function tone_at_1000

  subroutine require(condition,description)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: description
    if (.not. condition) then
       print '(a)', 'FAIL: '//description
       error stop 1
    endif
  end subroutine require
end program test_map65_q65_handoff
