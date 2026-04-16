# Driver for decoder smoke tests. Runs DECODER on SAMPLE and asserts that
# EXPECTED appears in stdout.
#
# Required variables (via -D on the cmake -P command line):
#   DECODER   absolute path to the decoder binary (use $<TARGET_FILE:...>)
#   SAMPLE    absolute path to a .wav sample
#   EXPECTED  single token that must appear in decoder stdout
# Optional:
#   MODE_FLAG single CLI flag placed before SAMPLE (e.g. "-8" for FT8)

if (NOT DECODER OR NOT SAMPLE OR NOT EXPECTED)
  message (FATAL_ERROR "run_decoder_test.cmake requires DECODER, SAMPLE, EXPECTED")
endif ()

set (_cmd ${DECODER})
if (DEFINED MODE_FLAG AND NOT MODE_FLAG STREQUAL "")
  list (APPEND _cmd ${MODE_FLAG})
endif ()
list (APPEND _cmd ${SAMPLE})

execute_process (
  COMMAND ${_cmd}
  OUTPUT_VARIABLE _out
  ERROR_VARIABLE  _err
  RESULT_VARIABLE _rc
)

if (NOT _rc EQUAL 0)
  message (FATAL_ERROR
    "Decoder exited with ${_rc}\n"
    "Command: ${_cmd}\n"
    "--- stdout ---\n${_out}\n--- stderr ---\n${_err}")
endif ()

string (FIND "${_out}" "${EXPECTED}" _pos)
if (_pos EQUAL -1)
  message (FATAL_ERROR
    "Expected token '${EXPECTED}' not found in decoder output.\n"
    "--- stdout ---\n${_out}\n--- stderr ---\n${_err}")
endif ()
