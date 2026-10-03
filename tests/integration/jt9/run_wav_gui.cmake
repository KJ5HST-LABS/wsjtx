foreach (required_variable WSJTX SAMPLE EXPECTED_MESSAGE WORK_DIR)
  if (NOT DEFINED ${required_variable} OR "${${required_variable}}" STREQUAL "")
    message (FATAL_ERROR "${required_variable} is required")
  endif ()
endforeach ()

string (RANDOM LENGTH 12 ALPHABET 0123456789abcdef run_id)
set (rig_name "CTEST-JT9-WAV-${run_id}")
set (ipc_dir "${WORK_DIR}-ipc")
file (REMOVE_RECURSE "${WORK_DIR}" "${ipc_dir}")
file (MAKE_DIRECTORY
  "${WORK_DIR}/config"
  "${WORK_DIR}/data"
  "${WORK_DIR}/cache"
  "${ipc_dir}")

set (wsjtx_environment
  "XDG_CONFIG_HOME=${WORK_DIR}/config"
  "XDG_DATA_HOME=${WORK_DIR}/data"
  "XDG_CACHE_HOME=${WORK_DIR}/cache"
  "WSJT_QMAP_SHARED_MEMORY_KEY=mem_qmap-test_wsjtx_jt9_wav")
if (NOT APPLE)
  list (APPEND wsjtx_environment "TMPDIR=${ipc_dir}")
endif ()
if (WIN32)
  list (APPEND wsjtx_environment
    "APPDATA=${WORK_DIR}/config"
    "LOCALAPPDATA=${WORK_DIR}/data"
    "TEMP=${ipc_dir}"
    "TMP=${ipc_dir}")
endif ()

execute_process (
  COMMAND "${CMAKE_COMMAND}" -E env
    ${wsjtx_environment}
    "${WSJTX}"
    --test-mode
    --jt9-wav-test "${SAMPLE}"
    --jt9-wav-expected "${EXPECTED_MESSAGE}"
    --rig-name "${rig_name}"
  WORKING_DIRECTORY "${WORK_DIR}"
  TIMEOUT 75
  RESULT_VARIABLE wsjtx_result
  OUTPUT_VARIABLE wsjtx_stdout
  ERROR_VARIABLE wsjtx_stderr)
file (WRITE "${WORK_DIR}/stdout.log" "${wsjtx_stdout}")
file (WRITE "${WORK_DIR}/stderr.log" "${wsjtx_stderr}")
if (NOT wsjtx_result STREQUAL "0")
  message (FATAL_ERROR
    "WSJT-X JT9 WAV test failed with exit code ${wsjtx_result}\n"
    "stdout:\n${wsjtx_stdout}\n"
    "stderr:\n${wsjtx_stderr}")
endif ()

message (STATUS "WSJT-X JT9 WAV decode and repeat passed")
