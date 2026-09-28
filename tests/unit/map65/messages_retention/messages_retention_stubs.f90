! Stand-in for the decoder's stdout channel: summarizes the "@" (Messages)
! and "&" (Band Map) lines one display() call sends to the GUI.
module stdout_channel_mod
  implicit none
  integer :: shown = 0, shown_at_utc = 0, want_utc = -1, oldest_utc = 9999
  integer :: mapped_calls = 0
  character(len=3) :: want_call_prefix = '???'
contains
  subroutine write_stdout(line)
    character(len=*), intent(in) :: line
    integer :: utc
    if (line(1:1) == '&') then
      ! "&" + kHz(3) + ndf(5) + " " + callsign(6) + age(2)
      if (len(line) >= 13) then
        if (line(11:13) == want_call_prefix) mapped_calls = mapped_calls + 1
      endif
      return
    endif
    if (line(1:1) /= '@') return
    shown = shown + 1
    read(line(20:23), '(i4)') utc         ! hhmm column of the "@" line
    if (utc == want_utc) shown_at_utc = shown_at_utc + 1
    oldest_utc = min(oldest_utc, utc)
  end subroutine
end module
