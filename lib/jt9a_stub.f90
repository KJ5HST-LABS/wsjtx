! Reject shared-memory worker mode in the streaming-only executable.
subroutine jt9a()
  use, intrinsic :: iso_fortran_env, only: error_unit
  write(error_unit,'(a)') 'jt9codec: GUI shared-memory worker mode is not available '// &
       'in the headless build. Use `jt9codec --stream` or `jt9codec <file.wav>`.'
  stop 2
end subroutine jt9a
