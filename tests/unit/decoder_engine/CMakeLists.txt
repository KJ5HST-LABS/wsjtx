add_library (test_decoder_engine_signal STATIC decoder_engine_signal.f90 jt9_engine_signal.f90)
set_target_properties (test_decoder_engine_signal PROPERTIES
  Fortran_MODULE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/signal-modules)
target_include_directories (test_decoder_engine_signal PRIVATE ${CMAKE_SOURCE_DIR}/lib)
wsjt_link_common_fortran (test_decoder_engine_signal)

add_executable (test_decoder_engine test_decoder_engine.c)
set_target_properties (test_decoder_engine PROPERTIES LINKER_LANGUAGE CXX)
target_include_directories (test_decoder_engine PRIVATE ${CMAKE_SOURCE_DIR})
target_link_libraries (test_decoder_engine PRIVATE test_decoder_engine_signal)
add_test (NAME test_decoder_engine COMMAND test_decoder_engine)
set_tests_properties (test_decoder_engine PROPERTIES TIMEOUT 90)

add_executable (test_decoder_engine_ft4 test_decoder_engine_ft4.c)
set_target_properties (test_decoder_engine_ft4 PROPERTIES LINKER_LANGUAGE CXX)
target_include_directories (test_decoder_engine_ft4 PRIVATE ${CMAKE_SOURCE_DIR})
target_link_libraries (test_decoder_engine_ft4 PRIVATE test_decoder_engine_signal)
add_test (NAME test_decoder_engine_ft4 COMMAND test_decoder_engine_ft4)
set_tests_properties (test_decoder_engine_ft4 PROPERTIES TIMEOUT 90)

find_package (Threads REQUIRED)
add_executable (test_decoder_engine_jt9 test_decoder_engine_jt9.c)
set_target_properties (test_decoder_engine_jt9 PROPERTIES LINKER_LANGUAGE CXX)
target_include_directories (test_decoder_engine_jt9 PRIVATE ${CMAKE_SOURCE_DIR})
target_link_libraries (test_decoder_engine_jt9 PRIVATE test_decoder_engine_signal Threads::Threads)
add_test (NAME test_decoder_engine_jt9 COMMAND test_decoder_engine_jt9)
add_test (NAME test_decoder_engine_jt9_small_stack COMMAND test_decoder_engine_jt9 --small-stack)
set_tests_properties (test_decoder_engine_jt9 test_decoder_engine_jt9_small_stack PROPERTIES TIMEOUT 90)

add_library (test_decoder_engine_jt65_signal STATIC
  ../jt65/jt65_test_fixture.f90 jt65_engine_signal.f90)
set_target_properties (test_decoder_engine_jt65_signal PROPERTIES
  Fortran_MODULE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/jt65-signal-modules)
target_link_libraries (test_decoder_engine_jt65_signal PUBLIC jt65_test_vectors)
wsjt_link_common_fortran (test_decoder_engine_jt65_signal)

add_executable (test_decoder_engine_jt65 test_decoder_engine_jt65.c)
set_target_properties (test_decoder_engine_jt65 PROPERTIES LINKER_LANGUAGE CXX)
target_include_directories (test_decoder_engine_jt65 PRIVATE ${CMAKE_SOURCE_DIR})
target_link_libraries (test_decoder_engine_jt65 PRIVATE test_decoder_engine_jt65_signal Threads::Threads)
add_test (NAME test_decoder_engine_jt65 COMMAND test_decoder_engine_jt65)
add_test (NAME test_decoder_engine_jt65_small_stack COMMAND test_decoder_engine_jt65 --small-stack)
set_tests_properties (test_decoder_engine_jt65 test_decoder_engine_jt65_small_stack PROPERTIES TIMEOUT 120)
add_test (NAME prepare_jt65_engine_wav COMMAND test_decoder_engine_jt65
  --write-wav ${CMAKE_CURRENT_BINARY_DIR}/jt65-engine.wav)
set_tests_properties (prepare_jt65_engine_wav PROPERTIES FIXTURES_SETUP jt65_engine_wav TIMEOUT 15)

add_executable (test_decoder_engine_jt65_host test_decoder_engine_jt65_host.f90)
target_link_libraries (test_decoder_engine_jt65_host PRIVATE test_decoder_engine_jt65_signal)
wsjt_link_common_fortran (test_decoder_engine_jt65_host)
file (MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/jt65-host)
add_test (NAME test_decoder_engine_jt65_host COMMAND test_decoder_engine_jt65_host)
set_tests_properties (test_decoder_engine_jt65_host PROPERTIES
  WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/jt65-host TIMEOUT 60)

if (TARGET wsjt_fort_omp)
  add_library (test_decoder_engine_signal_omp STATIC decoder_engine_signal.f90 jt9_engine_signal.f90)
  set_target_properties (test_decoder_engine_signal_omp PROPERTIES
    Fortran_MODULE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/signal-omp-modules)
  target_include_directories (test_decoder_engine_signal_omp PRIVATE
    ${WSJT_FORTRAN_OPENMP_MODULE_DIR} ${CMAKE_SOURCE_DIR}/lib)
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

  add_executable (test_decoder_engine_ft4_omp test_decoder_engine_ft4.c)
  set_target_properties (test_decoder_engine_ft4_omp PROPERTIES LINKER_LANGUAGE CXX)
  target_include_directories (test_decoder_engine_ft4_omp PRIVATE ${CMAKE_SOURCE_DIR})
  target_link_libraries (test_decoder_engine_ft4_omp PRIVATE test_decoder_engine_signal_omp)
  add_test (NAME test_decoder_engine_ft4_omp COMMAND test_decoder_engine_ft4_omp)
  set_tests_properties (test_decoder_engine_ft4_omp PROPERTIES
    ENVIRONMENT "OMP_DYNAMIC=FALSE;OMP_NUM_THREADS=2;OMP_THREAD_LIMIT=2"
    PROCESSORS 2
    TIMEOUT 90)

  add_executable (test_decoder_engine_jt9_omp test_decoder_engine_jt9.c)
  set_target_properties (test_decoder_engine_jt9_omp PROPERTIES LINKER_LANGUAGE CXX)
  target_include_directories (test_decoder_engine_jt9_omp PRIVATE ${CMAKE_SOURCE_DIR})
  target_link_libraries (test_decoder_engine_jt9_omp PRIVATE test_decoder_engine_signal_omp Threads::Threads)
  add_test (NAME test_decoder_engine_jt9_omp COMMAND test_decoder_engine_jt9_omp)
  add_test (NAME test_decoder_engine_jt9_omp_small_stack COMMAND test_decoder_engine_jt9_omp --small-stack)
  set_tests_properties (test_decoder_engine_jt9_omp test_decoder_engine_jt9_omp_small_stack PROPERTIES
    ENVIRONMENT "OMP_DYNAMIC=FALSE;OMP_NUM_THREADS=2;OMP_THREAD_LIMIT=2;OMP_STACKSIZE=1M"
    PROCESSORS 2
    TIMEOUT 90)

  add_library (test_decoder_engine_jt65_signal_omp STATIC
    ../jt65/jt65_test_fixture.f90 jt65_engine_signal.f90)
  set_target_properties (test_decoder_engine_jt65_signal_omp PROPERTIES
    Fortran_MODULE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/jt65-signal-omp-modules)
  target_link_libraries (test_decoder_engine_jt65_signal_omp PUBLIC
    jt65_test_vectors wsjt_fort_omp wsjt_fortran_openmp)

  add_executable (test_decoder_engine_jt65_omp test_decoder_engine_jt65.c)
  set_target_properties (test_decoder_engine_jt65_omp PROPERTIES LINKER_LANGUAGE CXX)
  target_include_directories (test_decoder_engine_jt65_omp PRIVATE ${CMAKE_SOURCE_DIR})
  target_link_libraries (test_decoder_engine_jt65_omp PRIVATE test_decoder_engine_jt65_signal_omp Threads::Threads)
  add_test (NAME test_decoder_engine_jt65_omp COMMAND test_decoder_engine_jt65_omp)
  add_test (NAME test_decoder_engine_jt65_omp_small_stack COMMAND test_decoder_engine_jt65_omp --small-stack)
  set_tests_properties (test_decoder_engine_jt65_omp test_decoder_engine_jt65_omp_small_stack PROPERTIES
    ENVIRONMENT "OMP_DYNAMIC=FALSE;OMP_NUM_THREADS=2;OMP_THREAD_LIMIT=2;OMP_STACKSIZE=1M"
    PROCESSORS 2
    TIMEOUT 120)
endif ()
