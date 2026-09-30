module decoder_codec_context
  use packjt77, only: pack77_state
  implicit none
  private
  public :: get_decoder_codec_state

  type(pack77_state), save, target :: gui_codec_state

contains

  function get_decoder_codec_state() result(state)
    type(pack77_state), pointer :: state
    state => gui_codec_state
  end function
end module decoder_codec_context
