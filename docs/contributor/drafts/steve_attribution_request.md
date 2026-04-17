Subject: Re: CI/CD Success! — attribution for your decoder test script

Steve,

Thanks again for sending over the decoder script and the v3.0.1 baseline — that's exactly the coverage we needed to close the Phase 3 item in our CI pipeline plan.

Two quick things before I vendor anything into the repo.

1. **Consent.** Can I confirm that you're OK with `decoder_tests.bash` and `decoder_test_results_v3.0.1.txt` being vendored under `tests/decoders/franke/reference/` in `KJ5HST-LABS/wsjtx-internal` under GPLv3 (the existing license of the surrounding source tree)? The script would go in as-is — attribution header prepended, no edits to your code — and would not be executed by CI. It's there as a reference for future contributors to see the original bug-bust corpus.

2. **Attribution.** How would you like the header to read? My default would be:

   ```
   # Decoder regression test corpus
   # Original author: Steven Franke (s.j.franke@icloud.com)
   # Vendored with permission under GPLv3, <date>
   # This file is kept as provenance for the decoder test catalog in
   # tests/decoders/CMakeLists.txt; it is not executed by CI.
   ```

   Happy to adjust — initials only, different email, different wording, omit the email — whatever you prefer.

One other thing you might appreciate knowing: our plan doesn't run your script directly in CI. The issue is platform portability (bash + sox + hard-coded paths wouldn't survive Linux / Windows runners cleanly). Instead, we're translating the 17 decoder invocations in your script into a data-driven ctest catalog — one `add_test()` per case, pure CMake driver, pre-processed samples committed once (so sox doesn't need to run at CI time). The catalog carries a `PROVENANCE` field on each entry pointing back to the corresponding block in your script. The coverage is preserved; the form changes.

For the expected-output check, we're picking the 2–3 highest-SNR decodes from your baseline as the pass condition ("at least one must appear"), so weak-decode drift between decoder revisions doesn't produce false alarms. If you have opinions on that approach — or if there are cases where the WEAK decodes are the regression signal — I'd want to know before we lock the catalog.

No rush on the reply. I'll hold the vendor commit until I hear back.

73,

Terrell
