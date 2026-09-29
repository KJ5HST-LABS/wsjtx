add_library (test_decoder_engine_signal STATIC decoder_engine_signal.f90)
wsjt_link_common_fortran (test_decoder_engine_signal)

add_executable (test_decoder_engine test_decoder_engine.c)
set_target_properties (test_decoder_engine PROPERTIES LINKER_LANGUAGE CXX)
target_include_directories (test_decoder_engine PRIVATE ${CMAKE_SOURCE_DIR})
target_link_libraries (test_decoder_engine PRIVATE test_decoder_engine_signal)
add_test (NAME test_decoder_engine COMMAND test_decoder_engine)
set_tests_properties (test_decoder_engine PROPERTIES TIMEOUT 90)

if (TARGET wsjt_fort_omp)
  add_library (test_decoder_engine_signal_omp STATIC decoder_engine_signal.f90)
  target_include_directories (test_decoder_engine_signal_omp PRIVATE
    ${WSJT_FORTRAN_OPENMP_MODULE_DIR})
  target_link_libraries (test_decoder_engine_signal_omp PUBLIC
    wsjt_fort_omp wsjt_fortran_openmp)

  add_executable (test_decoder_engine_omp test_decoder_engine.c)
  set_target_properties (test_decoder_engine_omp PROPERTIES LINKER_LANGUAGE CXX)
  target_include_directories (test_decoder_engine_omp PRIVATE ${CMAKE_SOURCE_DIR})
  target_link_libraries (test_decoder_engine_omp PRIVATE test_decoder_engine_signal_omp)
  add_test (NAME test_decoder_engine_omp COMMAND test_decoder_engine_omp)
  set_tests_properties (test_decoder_engine_omp PROPERTIES
    ENVIRONMENT "OMP_DYNAMIC=FALSE;OMP_NUM_THREADS=2;OMP_THREAD_LIMIT=2"
    PROCESSORS 2
    TIMEOUT 90)
endif ()
