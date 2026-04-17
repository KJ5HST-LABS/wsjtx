# Decoder regression test catalog. Drives jt9 and wsprd on in-tree .wav
# samples and asserts that strong baseline decodes survive. Each case is
# a bug-bust corpus entry; adding a case is one add_decoder_test() block.
#
# Labels:
#   smoke   — Phase 2 fast-path tests (run in seconds, two cases). `ctest -L smoke`
#   franke  — full Phase 3 catalog derived from Steven Franke's decoder_tests.bash
#             (16 cases). `ctest -L franke`.
#
# Registered only when both the decoder target and the sample(s) exist. This
# subdirectory must be added AFTER the decoder targets are defined in the
# root CMakeLists.txt.

include (CMakeParseArguments)

# add_decoder_test(
#   NAME            <test_name>
#   DECODER         <target>             (e.g. jt9, wsprd)
#   [OPTIONS        <arg> <arg> ...]     (list, passed to decoder as argv)
#   SAMPLES         <path> [<path> ...]  (list, passed positionally after options)
#   EXPECTED_TOKENS <tok> <tok> ...      (list, any-of match against stdout)
#   PROVENANCE      "<string>"           (origin note — required documentation)
# )
function (add_decoder_test)
  set (oneValueArgs NAME DECODER PROVENANCE)
  set (multiValueArgs OPTIONS SAMPLES EXPECTED_TOKENS)
  cmake_parse_arguments (ADT "" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

  foreach (_req NAME DECODER SAMPLES EXPECTED_TOKENS PROVENANCE)
    if (NOT DEFINED ADT_${_req} OR "${ADT_${_req}}" STREQUAL "")
      message (FATAL_ERROR "add_decoder_test: ${_req} is required")
    endif ()
  endforeach ()

  if (NOT TARGET ${ADT_DECODER})
    return ()
  endif ()
  foreach (_s IN LISTS ADT_SAMPLES)
    if (NOT EXISTS ${_s})
      return ()
    endif ()
  endforeach ()

  # Escape internal semicolons so each cmake-list argument survives list
  # storage and arrives at the child cmake -P as a single -D value.
  string (REPLACE ";" "\\;" _samples_esc "${ADT_SAMPLES}")
  string (REPLACE ";" "\\;" _tokens_esc "${ADT_EXPECTED_TOKENS}")

  set (_cmd ${CMAKE_COMMAND}
            -DDECODER=$<TARGET_FILE:${ADT_DECODER}>
            "-DSAMPLES=${_samples_esc}"
            "-DEXPECTED_TOKENS=${_tokens_esc}")
  if (ADT_OPTIONS)
    string (REPLACE ";" "\\;" _options_esc "${ADT_OPTIONS}")
    list (APPEND _cmd "-DOPTIONS=${_options_esc}")
  endif ()
  list (APPEND _cmd -P ${CMAKE_CURRENT_SOURCE_DIR}/run_decoder_test.cmake)

  add_test (
    NAME ${ADT_NAME}
    COMMAND ${_cmd}
    WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
  )
  set_tests_properties (${ADT_NAME} PROPERTIES LABELS "decoder;franke")
endfunction ()

# ----------------------------------------------------------------------
# Phase 2 smoke tests (label: smoke).
# ----------------------------------------------------------------------

if (TARGET jt9 AND EXISTS ${CMAKE_SOURCE_DIR}/samples/FT8/210703_133430.wav)
  add_test (
    NAME decoder_ft8_smoke
    COMMAND ${CMAKE_COMMAND}
      -DDECODER=$<TARGET_FILE:jt9>
      -DMODE_FLAG=-8
      -DSAMPLE=${CMAKE_SOURCE_DIR}/samples/FT8/210703_133430.wav
      -DEXPECTED=K1JT
      -P ${CMAKE_CURRENT_SOURCE_DIR}/run_decoder_test.cmake
    WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
  )
  set_tests_properties (decoder_ft8_smoke PROPERTIES LABELS "decoder;smoke")
endif ()

if (TARGET wsprd AND EXISTS ${CMAKE_SOURCE_DIR}/samples/WSPR/150426_0918.wav)
  add_test (
    NAME decoder_wspr_smoke
    COMMAND ${CMAKE_COMMAND}
      -DDECODER=$<TARGET_FILE:wsprd>
      -DSAMPLE=${CMAKE_SOURCE_DIR}/samples/WSPR/150426_0918.wav
      -DEXPECTED=ND6P
      -P ${CMAKE_CURRENT_SOURCE_DIR}/run_decoder_test.cmake
    WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
  )
  set_tests_properties (decoder_wspr_smoke PROPERTIES LABELS "decoder;smoke")
endif ()

# ----------------------------------------------------------------------
# Phase 3 Franke catalog (label: franke).
# Expected tokens are strong decodes (highest SNR) from the known-good
# baseline capture (Steven Franke, v3.0.1, 2026-04-15). Any-of matching
# tolerates weak-decode drift while pinning regressions on strong ones.
# ----------------------------------------------------------------------

add_decoder_test (
  NAME            decoder_fst4w_1800
  DECODER         jt9
  OPTIONS         -p;1800;-W;-d;3;-f;1500;-F;100;-q
  SAMPLES         ${CMAKE_SOURCE_DIR}/samples/FST4+FST4W/201230_0300.wav
  EXPECTED_TOKENS DL0HOT;JO60
  PROVENANCE      "Franke decoder_tests.bash — FST4W-1800"
)

add_decoder_test (
  NAME            decoder_fst4_60
  DECODER         jt9
  OPTIONS         -p;60;-7;-d;3;-L;900;-H;1400;-q
  SAMPLES         ${CMAKE_SOURCE_DIR}/samples/FST4+FST4W/210115_0058.wav
  EXPECTED_TOKENS K9KFR;EN71;N5TM
  PROVENANCE      "Franke decoder_tests.bash — FST4-60"
)

add_decoder_test (
  NAME            decoder_ft4_standard
  DECODER         jt9
  OPTIONS         -5;-d;3;-q
  SAMPLES         ${CMAKE_SOURCE_DIR}/samples/FT4/000000_000002.wav
  EXPECTED_TOKENS KA1YQC;KG4W;K7RL
  PROVENANCE      "Franke decoder_tests.bash — FT4"
)

add_decoder_test (
  NAME            decoder_ft8_standard
  DECODER         jt9
  OPTIONS         -8;-d;3;-q
  SAMPLES         ${CMAKE_SOURCE_DIR}/samples/FT8/210703_133430.wav
  EXPECTED_TOKENS W1FC;F5BZB;WM3PEN
  PROVENANCE      "Franke decoder_tests.bash — FT8 standard decoder"
)

add_decoder_test (
  NAME            decoder_ft8_mt
  DECODER         jt9
  OPTIONS         -8;-M;-N;1;-E;3;-q
  SAMPLES         ${CMAKE_SOURCE_DIR}/samples/FT8/210703_133430.wav
  EXPECTED_TOKENS W1FC;F5BZB;WM3PEN
  PROVENANCE      "Franke decoder_tests.bash — FT8 MT decoder (overlaps standard by design)"
)

add_decoder_test (
  NAME            decoder_jt4a
  DECODER         jt9
  OPTIONS         -4;-f;1250;-F;50;-b;A;-p;60;-X;96;-d;3;-q
  SAMPLES         ${CMAKE_SOURCE_DIR}/samples/JT4/JT4A/preprocessed/DF2ZC_070926_040700_12k_pad1.wav
  EXPECTED_TOKENS K1JT;DF2ZC;JO30
  PROVENANCE      "Franke decoder_tests.bash — JT4A (sample pre-processed: rate 12000, pad 0 1.0)"
)

add_decoder_test (
  NAME            decoder_jt4f
  DECODER         jt9
  OPTIONS         -4;-f;1200;-F;50;-b;F;-p;60;-X;96;-d;3;-q
  SAMPLES         ${CMAKE_SOURCE_DIR}/samples/JT4/JT4F/preprocessed/OK1KIR_141105_175700_12k_pad1.wav
  EXPECTED_TOKENS G3WDG;OK1KIR
  PROVENANCE      "Franke decoder_tests.bash — JT4F (sample pre-processed: rate 12000, pad 0 1.0)"
)

add_decoder_test (
  NAME            decoder_jt9
  DECODER         jt9
  OPTIONS         -9;-q
  SAMPLES         ${CMAKE_SOURCE_DIR}/samples/JT9/130418_1742.wav
  EXPECTED_TOKENS JA1KAU;PD0JAC;G7CNF
  PROVENANCE      "Franke decoder_tests.bash — JT9"
)

add_decoder_test (
  NAME            decoder_jt65b_avg_even
  DECODER         jt9
  OPTIONS         -6;-b;B;-X;96;-d;16;-f;1700;-F;100;-x;G4XYZ;-c;K1ABC;-q
  SAMPLES         ${CMAKE_SOURCE_DIR}/samples/JT65/JT65B/preprocessed/000000_0002_trim2.1_pad2.1.wav;${CMAKE_SOURCE_DIR}/samples/JT65/JT65B/preprocessed/000000_0004_trim2.1_pad2.1.wav;${CMAKE_SOURCE_DIR}/samples/JT65/JT65B/preprocessed/000000_0006_trim2.1_pad2.1.wav
  EXPECTED_TOKENS K1ABC;G4XYZ;IO91
  PROVENANCE      "Franke decoder_tests.bash — JT65B even-interval 3-file average"
)

add_decoder_test (
  NAME            decoder_jt65b_dl7uae
  DECODER         jt9
  OPTIONS         -6;-b;B;-X;96;-d;2;-f;1494;-F;50;-c;K1JT;-x;DL7UAE;-q
  SAMPLES         ${CMAKE_SOURCE_DIR}/samples/JT65/JT65B/preprocessed/DL7UAE_040308_002400_12k_pad3_trim3.wav
  EXPECTED_TOKENS K1JT;DL7UAE;JO62
  PROVENANCE      "Franke decoder_tests.bash — JT65B DL7UAE (sample pre-processed: rate 12000, pad 0 3.0, trim 3.0)"
)

add_decoder_test (
  NAME            decoder_msk144_120500
  DECODER         jt9
  OPTIONS         -k;-p;15;-q
  SAMPLES         ${CMAKE_SOURCE_DIR}/samples/MSK144/181211_120500.wav
  EXPECTED_TOKENS K1JT;WA4CQG;EM72
  PROVENANCE      "Franke decoder_tests.bash — MSK144 capture 181211_120500"
)

add_decoder_test (
  NAME            decoder_msk144_120800
  DECODER         jt9
  OPTIONS         -k;-p;15;-q
  SAMPLES         ${CMAKE_SOURCE_DIR}/samples/MSK144/181211_120800.wav
  EXPECTED_TOKENS KD9VV;EN71
  PROVENANCE      "Franke decoder_tests.bash — MSK144 capture 181211_120800"
)

add_decoder_test (
  NAME            decoder_q65_60a_eme_6m
  DECODER         jt9
  OPTIONS         -3;-b;A;-p;60;-f;1500;-F;100;-q
  SAMPLES         ${CMAKE_SOURCE_DIR}/samples/Q65/60A_EME_6m/preprocessed/210106_1621_trim2.5_pad2.5.wav
  EXPECTED_TOKENS W7GJ;VE1JF;W1VD
  PROVENANCE      "Franke decoder_tests.bash — Q65-60A 6m EME (sample pre-processed: trim 2.5, pad 0 2.5)"
)

add_decoder_test (
  NAME            decoder_q65_60d_eme_10ghz
  DECODER         jt9
  OPTIONS         -3;-b;D;-p;60;-X;96;-f;1000;-F;100;-q
  SAMPLES         ${CMAKE_SOURCE_DIR}/samples/Q65/60D_EME_10GHz/preprocessed/201212_1838_trim2.5_pad2.5.wav
  EXPECTED_TOKENS VK7MO;K6QPV;DM12
  PROVENANCE      "Franke decoder_tests.bash — Q65-60D 10 GHz EME (sample pre-processed: trim 2.5, pad 0 2.5)"
)

add_decoder_test (
  NAME            decoder_q65_120d_rainscatter
  DECODER         jt9
  OPTIONS         -3;-b;D;-p;120;-X;96;-f;1000;-F;20;-d;3;-q
  SAMPLES         ${CMAKE_SOURCE_DIR}/samples/Q65/120D_Rainscatter_10_GHz/210117_0920.wav
  EXPECTED_TOKENS VK3WE;VK7MO;QE37
  PROVENANCE      "Franke decoder_tests.bash — Q65-120D 10 GHz rainscatter"
)

add_decoder_test (
  NAME            decoder_wspr_franke
  DECODER         wsprd
  OPTIONS         -d;-C;500;-o;4
  SAMPLES         ${CMAKE_SOURCE_DIR}/samples/WSPR/150426_0918.wav
  EXPECTED_TOKENS ND6P;NM7J;WD4LHT
  PROVENANCE      "Franke decoder_tests.bash — WSPR with deep-search options"
)
