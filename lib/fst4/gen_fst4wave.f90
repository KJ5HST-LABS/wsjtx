module fst4_wavegen
  private
  public :: fst4_wavegen_workspace,gen_fst4wave_owned
  type fst4_wavegen_workspace
     complex, allocatable :: ctab(:)
     real, allocatable :: pulse(:),dphi(:),scaled_pulse(:)
     integer :: nsps=0
     real :: twopi=0,dt=0,tsym=0
     logical :: first=.true.,shape=.true.
  end type
contains
subroutine gen_fst4wave_owned(work,itone,nsym,nsps,nwave,fsample,hmod,f0,    &
   icmplx,cwave,wave)

   type(fst4_wavegen_workspace), intent(inout) :: work
   parameter(NTAB=65536)
   real wave(*)
   complex cwave(*)
   character(len=1) :: cvalue 
   integer hmod
   integer itone(nsym)

   if(work%first) then
      allocate(work%ctab(0:NTAB-1))
      work%twopi=8.0*atan(1.0)
      do i=0,NTAB-1
         phi=i*work%twopi/NTAB
         work%ctab(i)=cmplx(cos(phi),sin(phi))
      enddo
      call get_environment_variable("FST4_NOSHAPING",cvalue,nlen)
      if(nlen.eq.1 .and. cvalue.eq."1") work%shape=.false.
   endif

   if(work%first.or.nsps.ne.work%nsps) then
      if(allocated(work%pulse)) then
         if(size(work%pulse)<3*nsps) deallocate(work%pulse,work%dphi,work%scaled_pulse)
      endif
      if(.not.allocated(work%pulse)) &
         allocate(work%pulse(1:3*nsps),work%dphi(0:nsps-1),work%scaled_pulse(3*nsps))
      work%dt=1.0/fsample
      work%tsym=nsps/fsample
! Compute the smoothed frequency-deviation pulse
      do i=1,3*nsps
         tt=(i-1.5*nsps)/real(nsps)
         work%pulse(i)=gfsk_pulse(2.0,tt)
      enddo
      work%first=.false.
      work%nsps=nsps
   endif

! Generate one symbol at a time, retaining phase across symbol boundaries.
   dphi_peak=work%twopi*hmod/real(nsps)
   work%scaled_pulse(1:3*nsps)=dphi_peak*work%pulse(1:3*nsps)
   carrier=work%twopi*(f0-1.5*hmod/work%tsym)*work%dt
   if(icmplx.eq.0) wave(nsym*nsps+1:nwave)=0.
   if(icmplx.eq.1) cwave(nsym*nsps+1:nwave)=0.
   phi=0.0
   k=0
   do iblock=1,nsym
      work%dphi(0:nsps-1)=0.0
! Accumulate overlapping pulses in tone order to preserve phase rounding.
      do j=max(1,iblock-1),min(nsym,iblock+1)
         ip=(iblock-j+1)*nsps+1
         work%dphi(0:nsps-1)=work%dphi(0:nsps-1)+work%scaled_pulse(ip:ip+nsps-1)*itone(j)
      enddo
      work%dphi(0:nsps-1)=work%dphi(0:nsps-1)+carrier
      do j=0,nsps-1
         k=k+1
         i=phi*float(NTAB)/work%twopi
         i=iand(i,NTAB-1)
         if(icmplx.eq.0) then
            wave(k)=aimag(work%ctab(i))
         else
            cwave(k)=work%ctab(i)
         endif
         phi=phi+work%dphi(j)
         if(phi.gt.work%twopi) phi=phi-work%twopi
      enddo
   enddo

! Apply the symbol amplitude envelope.
   if(work%shape) then
      k1=(nsym-1)*nsps+3*nsps/4+1
      do i=0,nsps/4-1
         envelope=(1.0-cos(work%twopi*i/real(nsps/2)))/2.0
         if(icmplx.eq.0) then
            wave(i+1)=wave(i+1)*envelope
         else
            cwave(i+1)=cwave(i+1)*envelope
         endif
      enddo
      do i=0,nsps/4
         envelope=(1.0+cos(work%twopi*i/real(nsps/2)))/2.0
         if(icmplx.eq.0) then
            wave(k1+i)=wave(k1+i)*envelope
         else
            cwave(k1+i)=cwave(k1+i)*envelope
         endif
      enddo
   endif

   return
end subroutine gen_fst4wave_owned
end module fst4_wavegen

subroutine gen_fst4wave(itone,nsym,nsps,nwave,fsample,hmod,f0,icmplx,cwave,wave)
   use fst4_wavegen, only: fst4_wavegen_workspace,gen_fst4wave_owned
   type(fst4_wavegen_workspace), save :: legacy
   integer itone(nsym),hmod
   real wave(*),fsample,f0
   complex cwave(*)
   call gen_fst4wave_owned(legacy,itone,nsym,nsps,nwave,fsample,hmod,f0,icmplx,cwave,wave)
end subroutine
