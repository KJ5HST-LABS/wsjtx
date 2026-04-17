# Driver for decoder tests. Runs DECODER on one or more samples and asserts
# that at least one of the expected tokens appears in stdout.
#
# Required variables (via -D on the cmake -P command line):
#   DECODER          absolute path to the decoder binary (use $<TARGET_FILE:...>)
#
# Sample inputs — provide exactly one of:
#   SAMPLE           single .wav path (single-sample shorthand)
#   SAMPLES          semicolon-separated list of .wav paths, passed as positional
#                    args to the decoder in the given order
#
# Expected output — provide exactly one of:
#   EXPECTED         single token that must appear in decoder stdout
#   EXPECTED_TOKENS  semicolon-separated list; pass if ANY token appears in stdout
#
# Decoder arguments — at most one of:
#   OPTIONS          semicolon-separated list of CLI args placed before the
#                    sample(s) (e.g. "-8;-d;3;-q" for FT8 standard decoder)
#   MODE_FLAG        single CLI flag placed before the sample(s) (legacy alias
#                    retained for Phase 2 smoke tests)

if (NOT DECODER)
  message (FATAL_ERROR "run_decoder_test.cmake requires DECODER")
endif ()

if (SAMPLE AND SAMPLES)
  message (FATAL_ERROR "run_decoder_test.cmake: specify SAMPLE or SAMPLES, not both")
endif ()
if (NOT SAMPLE AND NOT SAMPLES)
  message (FATAL_ERROR "run_decoder_test.cmake requires SAMPLE or SAMPLES")
endif ()

if (EXPECTED AND EXPECTED_TOKENS)
  message (FATAL_ERROR "run_decoder_test.cmake: specify EXPECTED or EXPECTED_TOKENS, not both")
endif ()
if (NOT EXPECTED AND NOT EXPECTED_TOKENS)
  message (FATAL_ERROR "run_decoder_test.cmake requires EXPECTED or EXPECTED_TOKENS")
endif ()

if (OPTIONS AND MODE_FLAG)
  message (FATAL_ERROR "run_decoder_test.cmake: specify OPTIONS or MODE_FLAG, not both")
endif ()

# Normalize single-value aliases into list form.
set (_samples ${SAMPLES})
if (SAMPLE)
  set (_samples "${SAMPLE}")
endif ()

set (_tokens ${EXPECTED_TOKENS})
if (EXPECTED)
  set (_tokens "${EXPECTED}")
endif ()

set (_cmd ${DECODER})
if (OPTIONS)
  list (APPEND _cmd ${OPTIONS})
elseif (MODE_FLAG)
  list (APPEND _cmd ${MODE_FLAG})
endif ()
list (APPEND _cmd ${_samples})

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

set (_matched "")
foreach (_token IN LISTS _tokens)
  string (FIND "${_out}" "${_token}" _pos)
  if (NOT _pos EQUAL -1)
    set (_matched "${_token}")
    break ()
  endif ()
endforeach ()

if (NOT _matched)
  message (FATAL_ERROR
    "None of the expected tokens found in decoder output.\n"
    "Tokens: ${_tokens}\n"
    "Command: ${_cmd}\n"
    "--- stdout ---\n${_out}\n--- stderr ---\n${_err}")
endif ()
