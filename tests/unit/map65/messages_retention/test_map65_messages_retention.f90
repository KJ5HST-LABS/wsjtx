program test_map65_messages_retention
  use iso_fortran_env, only: real64
  use stdout_channel_mod
  use display_mod, only: display
  implicit none
  integer :: minute, missed, nrec

  ! A light band keeps exactly Timeout minutes of history.
  call run_band(40, 3, 60, missed, nrec)
  call require(missed == 0, 'light band: every minute''s decodes are shown')
  call require(oldest_utc == 1219, '40-minute timeout keeps 40 minutes (1219-1259)')
  call run_band(10, 3, 60, missed, nrec)
  call require(oldest_utc == 1249, '10-minute timeout keeps 10 minutes (1249-1259)')

  ! A busy band overflows the display() window. The newest decodes must
  ! still be shown every minute, and the history file must stay bounded.
  call run_band(40, 25, 120, missed, nrec)
  call require(missed == 0, 'busy band: newest decodes shown every minute')
  call require(nrec <= 800, 'busy band: history file stays bounded')
  call run_band(20, 18, 120, missed, nrec)
  call require(missed == 0, '20-minute timeout, 18 decodes/min: newest shown every minute')
  print '(a)', 'MAP65 Messages retention tests passed.'

contains
  ! Simulate map65a's writes to unit 26: each minute an early pass writes
  ! per_min decodes plus an end-of-pass marker, and a final pass writes
  ! another marker; display() runs after each pass. missed counts minutes
  ! whose decodes were not all in the Messages window after the final pass.
  subroutine run_band(nkeep, per_min, minutes, missed, nrec)
    integer, intent(in) :: nkeep, per_min, minutes
    integer, intent(out) :: missed, nrec
    integer :: k, nutc, ios
    character(len=22) :: msg
    character(len=83) :: rec
    real(real64) :: f0
    open(26, status='scratch')
    missed = 0
    do minute = 0, minutes - 1
      nutc = 100*(12 + minute/60) + mod(minute, 60)
      do k = 1, per_min
        f0 = 144.0_real64 + 0.001_real64*(100 + 3*k)
        write(msg, '(a,i3.3,a)') 'CQ K', k, 'X FN42'
        write(26, 1014) f0, 0, 0, 0, 0, 0.0, 0, 5, -20, nutc, msg, '#', ' ', '#B'
      enddo
      write(26, 1015) nutc
      call display(nkeep, 0.010)
      write(26, 1015) nutc
      shown = 0; shown_at_utc = 0; want_utc = nutc; oldest_utc = 9999
      call display(nkeep, 0.010)
      if (shown_at_utc /= per_min) missed = missed + 1
    enddo
    rewind(26)
    nrec = 0
    do
      read(26, '(a83)', iostat=ios) rec
      if (ios /= 0) exit
      nrec = nrec + 1
    enddo
    close(26)
1014 format(f8.3, i5, 3i3, f5.1, i4, i3, i4, i5.4, 4x, a22, 7x, 2a1, 2x, a2)
1015 format(37x, i6.4, ' ')
  end subroutine

  subroutine require(condition, description)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: description
    if (.not. condition) then
      print '(a)', 'FAIL: '//description
      error stop 1
    endif
  end subroutine
end program
