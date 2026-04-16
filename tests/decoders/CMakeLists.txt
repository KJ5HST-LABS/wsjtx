# Decoder smoke tests. Drive jt9 (FT8) and wsprd (WSPR) on in-tree .wav
# samples and assert a stable callsign appears in the decoded output.
#
# Registered only when both the decoder target and the sample exist. This
# subdirectory must be added AFTER the decoder targets are defined in the
# root CMakeLists.txt.

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
endif ()
