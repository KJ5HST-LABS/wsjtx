subroutine decoder_engine_test_signal(samples,payload) bind(C)
  use iso_c_binding, only: c_int8_t,c_int16_t,c_int64_t
  use packjt77, only: pack77_state
  use ft8_codec_context, only: genft8_for_state
  implicit none
  integer, parameter :: symbol_samples=1920,wave_samples=79*symbol_samples
  integer(c_int16_t), intent(out) :: samples(180000)
  integer(c_int8_t), intent(out) :: payload(77)
  type(pack77_state) :: knowledge
  real :: wave(wave_samples)
  complex :: complex_wave(1)
  integer :: tones(79),i3,n3,i
  integer(c_int64_t) :: random_state
  character(len=37) :: message,sent

  message='CQ K1JT FN20'
  i3=-1
  n3=-1
  call genft8_for_state(knowledge,message,i3,n3,sent,payload,tones)
  if(sent.ne.message) error stop 'engine test waveform message did not encode'
  call gen_ft8wave(tones,79,symbol_samples,2.0,12000.0,1500.0, &
       complex_wave,wave,0,wave_samples)
  random_state=1234567_c_int64_t
  do i=1,size(samples)
     random_state=mod(16807_c_int64_t*random_state,2147483647_c_int64_t)
     samples(i)=int(mod(random_state,21_c_int64_t)-10_c_int64_t,c_int16_t)
  enddo
  samples(6001:6000+wave_samples)=samples(6001:6000+wave_samples)+int(1500.0*wave,c_int16_t)
end subroutine decoder_engine_test_signal

subroutine decoder_engine_test_residual(samples) bind(C)
  use iso_c_binding, only: c_float
  use ft8_mod1, only: dd8
  implicit none
  real(c_float), intent(out) :: samples(180000)
  samples=dd8
end subroutine

subroutine decoder_engine_test_host_windows() bind(C)
  use iso_c_binding, only: c_short,c_int8_t,c_int64_t,c_sizeof
  use decoder_engine, only: engine_host_decode
  use ft8_engine_kernel, only: params_block
  use ft8_mod1, only: dd8
  use decode_completion_module, only: decode_completion_result
  implicit none
  type(params_block) :: params
  type(decode_completion_result) :: completion
  integer(c_int8_t) :: zeros(c_sizeof(params))
  integer(c_short), target :: samples(180000)
  integer :: extent,case_no

  zeros=0
  params=transfer(zeros,params)
  params%nmode=8
  params%ntr=15
  params%nutc=120000
  params%nzhsym=49
  params%newdat=.true.
  params%lmultift8=.true.
  params%nmt=1
  params%nfqso=3000
  params%nfa=1000
  params%nfb=2000
  params%nagainfil=.true.
  params%mycall=' '
  params%mybcall=' '
  params%hiscall=' '
  params%hisbcall=' '
  params%mygrid=' '
  params%hisgrid=' '
  samples=2
  do case_no=1,2
     extent=180000
     if(case_no==2) extent=100000
     call engine_host_decode(samples,params,12000,completion,0, &
          int(900+case_no,c_int64_t),int(900+case_no,c_int64_t),1,extent)
     extent=min(extent,49*3456)
     if(any(dd8(:extent)/=2.0)) error stop 'host discarded available MTD audio'
     if(any(dd8(extent+1:)/=0.0)) error stop 'host retained audio outside the MTD window'
     if(.not.completion%available) error stop 'host window probe did not complete'
  enddo
end subroutine
