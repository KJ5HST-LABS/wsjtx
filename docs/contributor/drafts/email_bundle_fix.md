**Subject:** Re: Crashing on Display of Astronomical Data?

Steve, Brian,

Thanks for pulling me in. I've been building WSJT-X on ARM Mac for a while now and ran into both of these.

Brian, your POST_BUILD fix for jt9 looks right. A couple of things that might also need the same treatment:

- **wsprd** — wsjtx launches it as a subprocess the same way it does jt9. Same bundle copy issue on ARM.
- **JPLEPH** — as Steve noted. The install() rule on line 1854 handles it for `make install`, but running from the build directory it's not in the bundle. Would need a POST_BUILD copy to `wsjtx.app/Contents/Resources/wsjtx/JPLEPH`.
- **Other data files** — that same install block copies cty.dat, grid.dat, sat.dat, and eclipse.txt. Those may also be missing when running from the build directory, which could cause quieter failures.

One small nit on the CMake — `$<TARGET_FILE:jt9>` would be more robust than `${CMAKE_BINARY_DIR}/jt9` for the source path, in case the binary ends up somewhere else in the build tree.

I can put together a standalone PR for just the bundle fixes (jt9 + wsprd + JPLEPH + data files) if that would be helpful. Brian's PR #5 has a lot of other refactoring in it and this seems like something that could go in independently.

Question on timing — is this something we should get in before GA, or is it better to wait until after the release? I don't want to introduce churn this close to April 8.

73, Terrell KJ5HST
