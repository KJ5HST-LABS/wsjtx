module decoder_engine_types
  use, intrinsic :: iso_c_binding
  implicit none
  private
  public :: ft8_signal_evidence, ft4_signal_evidence, superfox_evidence, superfox_observation
  public :: engine_payload_none,engine_payload_decoded,engine_payload_hypothesis
  public :: sf_kind_cq,sf_kind_exchange,sf_kind_free_text,sf_kind_verification
  public :: engine_observation, engine_observation_sink, engine_superfox_sink
  public :: engine_abi,engine_mode_ft8,engine_mode_ft4,engine_support_ft8,engine_support_ft4

  integer(c_int), parameter :: engine_abi=3,engine_mode_ft8=8,engine_mode_ft4=5
  integer(c_int), parameter :: engine_support_ft8=1,engine_support_ft4=2

  integer, parameter :: engine_payload_none=0,engine_payload_decoded=1,engine_payload_hypothesis=2
  integer, parameter :: sf_kind_cq=1,sf_kind_exchange=2,sf_kind_free_text=3,sf_kind_verification=4

  type, bind(C) :: ft8_signal_evidence
     integer(c_int8_t) :: payload77(77)=0,tones(79)=0
     integer(c_int) :: payload_origin=engine_payload_none,has_tones=0,has_waveform_start=0,method=0
     real(c_float) :: waveform_start_seconds=0.0
  end type

  type, bind(C) :: ft4_signal_evidence
     integer(c_int8_t) :: payload77(77)=0,tones(103)=0
     integer(c_int) :: payload_origin=engine_payload_none,has_tones=0,has_waveform_start=0,method=0
     real(c_float) :: waveform_start_seconds=0.0
  end type

  type, bind(C) :: superfox_evidence
     integer(c_int8_t) :: symbols(50)=0
     integer(c_int) :: kind=0,child_index=0
  end type

  type :: superfox_observation
     integer(c_int8_t) :: symbols(50)=0
     integer(c_int) :: kind=0,child_index=0,snr_db=0
     real(c_float) :: frequency_hz=0.0,dt_seconds=0.0
     character(len=37) :: message=''
     character(len=160) :: legacy_line=''
     integer(c_int) :: legacy_line_length=0
  end type

  type, bind(C) :: engine_observation
     integer(c_int64_t) :: input_id=0,analysis_id=0
     integer(c_int) :: attempt_no=0,mode=engine_mode_ft8,variant=0
     integer(c_int) :: snr_db=0,ap_type=0
     real(c_float) :: frequency_hz=0,dt_seconds=0,sync=0,quality=0
     character(c_char) :: message(38)=c_null_char
     type(ft8_signal_evidence) :: ft8
     type(ft4_signal_evidence) :: ft4
     type(superfox_evidence) :: superfox
  end type

  abstract interface
     subroutine engine_observation_sink(user,observation)
       import :: c_ptr,engine_observation
       type(c_ptr), intent(in) :: user
       type(engine_observation), intent(in) :: observation
     end subroutine
     subroutine engine_superfox_sink(user,observation)
       import :: c_ptr,superfox_observation
       type(c_ptr), intent(in) :: user
       type(superfox_observation), intent(in) :: observation
     end subroutine
  end interface
end module decoder_engine_types
