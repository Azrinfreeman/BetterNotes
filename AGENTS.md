# BetterNotes working rules

## Save time and tokens

- Complete the requested work with the smallest sufficient set of reads, edits, and checks. Preserve correctness and the user's requirements.
- Reuse facts and completed work from the current conversation. Read `STATUS.md` for project state when context is missing; consult `README.md` or `IMPLEMENTATION.md` only when needed.
- Search with `rg` in the relevant files or folders first. Exclude generated folders such as `build`, `dist`, `.dart_tool`, and `.tools` from broad searches. Read matching sections rather than dumping whole files.
- Batch independent reads and searches. Keep dependent edits and checks sequential. Request compact output and summarize failures instead of repeating long logs.
- Do not repeat discovery, SDK checks, dependency installation, analysis, builds, tests, or UI checks already completed for the same relevant state. Repeat only after an affecting change, a failure, stale or missing evidence, or an explicit user requirement.
- If a command fails because of a known environment restriction, use the established permitted solution. Do not retry the same failing approach without new evidence.
- Use tools and workflows already available. Avoid new dependencies, abstractions, helper scripts, or agents unless the task needs them. Do not delegate without explicit authorization.

## Choose verification to match the change

- Documentation or instruction edits: inspect the changed text; do not run Flutter builds or tests.
- Dart edits: format changed files and run static analysis once after related edits are complete. Run existing tests relevant to changed behavior when they provide useful coverage.
- Native Windows edits: compile Windows once after code is settled; check the affected Windows behavior. Do not rebuild web or mobile unless shared changes create a concrete risk there.
- Use a focused manual check when it gives better evidence than a test that merely duplicates the implementation. Add tests for meaningful regression risks, not routine reversible edits.
- After a check passes, repeat it only if later changes could invalidate it. Group fixes before rerunning expensive checks.
- Build and package once at the end when a runnable deliverable is requested or needed. Bump versions only for a release, not instruction or documentation edits.
- Never describe older checks as verification of newer code. State what was checked and any remaining limitation honestly.

## Reuse project knowledge

- Flutter SDK: `C:\Users\azrin\develop\flutter`; prefer this established installation over rediscovering or reinstalling it.
- This checkout has a local Git repository on `main`, initialized on 2026-10-08. Commit only when requested; generated builds, portable packages, and local cloud configuration are ignored.
- Cloud verification requires the owner's Supabase/Google configuration. Android packaging requires the Android SDK; iOS packaging requires a Mac with Xcode. Recheck these dependencies only when the user changes the setup or the task needs them.
- Maintain `STATUS.md` with concise, relevant changes and verification outcomes. Do not create duplicate progress documents or append full command transcripts.
- Keep progress updates brief and focused on findings, next actions, or blockers. Final responses should give the outcome, artifact link when relevant, verification, and material limits.

## Exceptions

Depart from these efficiency rules only when necessary for correctness, safety, required checks, changed evidence, or the user's request. Briefly explain a material exception. Never skip a required approval or check to save tokens, and never let efficiency become a reason to leave authorized work unfinished.
