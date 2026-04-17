# Fortran unit tests (pFUnit). Each .pf file defines a module with one or
# more @test subroutines; add_pfunit_ctest compiles it into a standalone
# test executable and registers it with ctest.
#
# The unit-under-test .f90 files are compiled directly (OTHER_SOURCES)
# rather than linked via wsjt_fort, so the test executables are hermetic
# and don't pull in the library's transitive FFTW3/OpenMP/Boost deps.
#
# This subdirectory must be added AFTER find_package(PFUNIT) runs in the
# root CMakeLists.txt.

add_pfunit_ctest (pfunit_chkcall
  TEST_SOURCES test_chkcall.pf
  OTHER_SOURCES ${CMAKE_SOURCE_DIR}/lib/chkcall.f90
)

add_pfunit_ctest (pfunit_grid2deg
  TEST_SOURCES test_grid2deg.pf
  OTHER_SOURCES ${CMAKE_SOURCE_DIR}/lib/grid2deg.f90
)
