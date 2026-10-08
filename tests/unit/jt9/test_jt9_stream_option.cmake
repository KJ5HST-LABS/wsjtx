# SPDX-License-Identifier: GPL-3.0-or-later
# jt9 refuses --stream and -0 before writing anything and names jt9codec;
# jt9codec refuses -s, names its stream, and names itself in its diagnostics.
# jt9's help offers the shared-memory worker and not the stream; jt9codec's
# offers the stream and not the worker.
file (REMOVE_RECURSE "${WORK_DIR}")
file (MAKE_DIRECTORY "${WORK_DIR}")
file (WRITE "${WORK_DIR}/empty" "")

# Runs program with args in a fresh, empty directory that is also its default
# data and temporary directory, with empty stdin.
function (run_fresh name program)
  set (directory "${WORK_DIR}/${name}")
  file (MAKE_DIRECTORY "${directory}")
  execute_process (
    COMMAND "${program}" ${ARGN}
    WORKING_DIRECTORY "${directory}"
    INPUT_FILE "${WORK_DIR}/empty"
    RESULT_VARIABLE result
    OUTPUT_VARIABLE stdout
    ERROR_VARIABLE stderr)
  file (GLOB written "${directory}/*")
  set (result "${result}" PARENT_SCOPE)
  set (stdout "${stdout}" PARENT_SCOPE)
  set (stderr "${stderr}" PARENT_SCOPE)
  set (written "${written}" PARENT_SCOPE)
endfunction ()

foreach (option --stream -0)
  run_fresh ("jt9${option}" "${JT9}" ${option})
  if (NOT result EQUAL 2 OR NOT stdout STREQUAL "" OR NOT stderr MATCHES "Use `jt9codec --stream`")
    message (FATAL_ERROR "jt9 ${option} did not refuse and name jt9codec (exit ${result}): ${stdout}${stderr}")
  endif ()
  if (written)
    message (FATAL_ERROR "jt9 ${option} wrote before refusing: ${written}")
  endif ()
endforeach ()

run_fresh (jt9codec--stream "${JT9CODEC}" --stream)
set (stream_result "${result}")
set (stream_stdout "${stdout}")
run_fresh (jt9codec-0 "${JT9CODEC}" -0)
if (NOT result EQUAL 1 OR NOT stdout MATCHES "\"short header" OR NOT result EQUAL stream_result
    OR NOT stdout STREQUAL stream_stdout)
  message (FATAL_ERROR "jt9codec -0 did not run the stream as --stream does (exit ${result}): ${stdout}${stderr}")
endif ()

run_fresh (jt9codec-s "${JT9CODEC}" -s nokey)
if (NOT result EQUAL 2 OR NOT stderr MATCHES "Use `jt9codec --stream`")
  message (FATAL_ERROR "jt9codec -s did not refuse and name its stream (exit ${result}): ${stdout}${stderr}")
endif ()

run_fresh (jt9codec-Q "${JT9CODEC}" -Q 6)
if (NOT result EQUAL 2 OR NOT stderr MATCHES "jt9codec: invalid value for -Q")
  message (FATAL_ERROR "jt9codec did not name itself in a diagnostic (exit ${result}): ${stdout}${stderr}")
endif ()

# Each help describes only the program that prints it.
function (check_help program)
  cmake_parse_arguments (PARSE_ARGV 1 help "" "" "OFFERS;OMITS")
  execute_process (
    COMMAND "${program}" --help
    RESULT_VARIABLE result
    OUTPUT_VARIABLE stdout
    ERROR_VARIABLE stderr)
  if (NOT result EQUAL 0)
    message (FATAL_ERROR "${program} --help exited ${result}: ${stdout}${stderr}")
  endif ()
  foreach (pattern IN LISTS help_OFFERS)
    if (NOT stdout MATCHES "${pattern}")
      message (FATAL_ERROR "${program} --help does not show '${pattern}':\n${stdout}")
    endif ()
  endforeach ()
  foreach (pattern IN LISTS help_OMITS)
    if (stdout MATCHES "${pattern}")
      message (FATAL_ERROR "${program} --help must not show '${pattern}':\n${stdout}")
    endif ()
  endforeach ()
endfunction ()

check_help ("${JT9}"
  OFFERS "Usage: jt9 \\[OPTIONS\\]" "jt9 -s <key>" "\n -s NAME" "\n --shmem NAME" "\n --ipc-lock PATH"
  OMITS "--stream" "jt9codec")
check_help ("${JT9CODEC}"
  OFFERS "Usage: jt9codec \\[OPTIONS\\]" "jt9codec --stream" "\n --stream"
  OMITS "Usage: jt9 " "-s <key>" "\n -s NAME" "--shmem" "--ipc-lock")
