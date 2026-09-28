! Stand-in for the decoder's stdout channel: summarizes the "@" lines one
! display() call sends to the Messages window.
module stdout_channel_mod
  implicit none
  integer :: shown = 0, shown_at_utc = 0, want_utc = -1, oldest_utc = 9999
contains
  subroutine write_stdout(line)
    character(len=*), intent(in) :: line
    integer :: utc
    if (line(1:1) /= '@') return
    shown = shown + 1
    read(line(20:23), '(i4)') utc         ! hhmm column of the "@" line
    if (utc == want_utc) shown_at_utc = shown_at_utc + 1
    oldest_utc = min(oldest_utc, utc)
  end subroutine
end module
