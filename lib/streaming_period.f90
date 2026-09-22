! Period bookkeeping for the streaming reader. A period is TRperiod * 12 kHz
! samples; the decoder takes the first npts of them; a frame that straddles
! the boundary carries its remainder into the next period.
module streaming_period
  implicit none
  private
  public :: period_state, period_begin, period_room, period_take,          &
       period_full, period_ready

  integer, parameter, public :: PERIOD_NFSAMPLE = 12000

  type period_state
     integer :: nperiod = 0   ! samples in the period
     integer :: npts    = 0   ! of them, the samples the decoder takes
     integer :: kperiod = 0   ! consumed so far this period
     integer :: k       = 0   ! handed to the decoder so far
  end type period_state

contains

  ! Begin a period of trperiod seconds in jt9 mode number `mode`, with a
  ! decoder buffer of nmax samples. The decoder's share is mode-dependent
  ! (21*3456 for FT4, at most 50*3456 for FT8); the period is never shorter
  ! than that share.
  subroutine period_begin(st, trperiod, mode, nmax)
    type(period_state), intent(out) :: st
    real(8),            intent(in)  :: trperiod
    integer,            intent(in)  :: mode, nmax
    st%npts = int(trperiod * PERIOD_NFSAMPLE)
    if (mode .eq. 5) st%npts = 21 * 3456
    if (mode .eq. 8 .and. st%npts .gt. 50 * 3456) st%npts = 50 * 3456
    if (st%npts .gt. nmax) st%npts = nmax
    if (st%npts .lt. 1) st%npts = PERIOD_NFSAMPLE
    st%nperiod = max(int(trperiod * PERIOD_NFSAMPLE), st%npts)
    st%kperiod = 0
    st%k       = 0
  end subroutine period_begin

  ! Of navail samples on offer, how many the period takes — never past its
  ! end, so what is left of a straddling frame is the next period's.
  pure integer function period_room(st, navail)
    type(period_state), intent(in) :: st
    integer,            intent(in) :: navail
    period_room = max(0, min(navail, st%nperiod - st%kperiod))
  end function period_room

  ! Account for ntake samples consumed into the period; the first nacc of
  ! them are the decoder's.
  subroutine period_take(st, ntake, nacc)
    type(period_state), intent(inout) :: st
    integer,            intent(in)    :: ntake
    integer,            intent(out)   :: nacc
    nacc = max(0, min(ntake, st%npts - st%k))
    st%kperiod = st%kperiod + ntake
    st%k       = st%k + nacc
  end subroutine period_take

  ! Every sample of the period is in.
  pure logical function period_full(st)
    type(period_state), intent(in) :: st
    period_full = st%kperiod .ge. st%nperiod
  end function period_full

  ! The decoder's samples are in.
  pure logical function period_ready(st)
    type(period_state), intent(in) :: st
    period_ready = st%k .ge. st%npts
  end function period_ready

end module streaming_period
