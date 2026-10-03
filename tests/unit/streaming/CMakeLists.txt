add_executable (test_streaming_consumers test_streaming_consumers.cpp)
add_dependencies (test_streaming_consumers test_decoder_engine_q65)
target_link_libraries (test_streaming_consumers Qt5::Test)
target_compile_definitions (test_streaming_consumers PRIVATE
  JT9_EXECUTABLE="$<TARGET_FILE:jt9>"
  WSPRD_EXECUTABLE="$<TARGET_FILE:wsprd>"
  Q65_ENGINE_WAV="${CMAKE_BINARY_DIR}/tests/unit/decoder_engine/q65-engine.wav"
)

add_test (NAME test_streaming_consumers COMMAND test_streaming_consumers)
set_tests_properties (test_streaming_consumers PROPERTIES
  LABELS "streaming;runtime"
  TIMEOUT 120
  FIXTURES_REQUIRED q65_engine_wav
)
if (WSJT_ENABLE_TSAN)
  set_tests_properties (test_streaming_consumers PROPERTIES
    ENVIRONMENT "TSAN_OPTIONS=${wsjt_tsan_fortran_options}")
endif ()

add_executable (test_streaming_period test_streaming_period.f90)
wsjt_link_common_fortran (test_streaming_period)
add_test (NAME test_streaming_period COMMAND test_streaming_period)
set_tests_properties (test_streaming_period PROPERTIES LABELS "streaming")
