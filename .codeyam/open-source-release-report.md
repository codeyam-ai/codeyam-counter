# Open-Source Release Report

**Repo:** codeyam-ai/codeyam-counter (transferred from jaredcosulich/codeyam-counter)
**Final visibility:** public
**License:** MIT (Copyright (c) 2026 Codeyam)
**Completed:** 2026-06-29

## Audit results

- **codeyam-audit / project gate:** passed. The project is codeyam-initialized;
  `editor audit` reported passed (16 glossary entries, 16 tests covered, no
  stale/missing). Swift `AppCore` package has zero external dependencies, so no
  dependency-license compatibility risk. CI (`swift build` + `swift test`) green
  on the final `main`.
- **Secret scan:** clean. gitleaks reports 7 hits, ALL in
  `.codeyam/.last-reconcile.json` (`generic-api-key` rule firing on the
  reconcile cache's SHA-256 `body_hashes`). Verified as content hashes, not
  credentials — false positives, left in place.
- **Internal-reference scrub:** one real finding — the editor-internal
  `review-session` skill was installed in the repo and carried absolute
  `/Users/jaredcosulich/.../codeyam-editor/.codeyam/plans/` paths in its
  `SKILL.md` and `find-last-session.mjs`. Removed from the working tree,
  gitignored to stop `init` re-adding it, and **purged from all git history**
  via `git filter-repo --path .claude/skills/review-session/ --invert-paths`
  followed by a force-push. Published history verified free of `review-session`
  and any `/Users/` path.
- **License & dependency check:** MIT LICENSE added (none existed); zero external
  deps → compatible.

## Documents added / polished

- `LICENSE` — MIT, 2026 Codeyam
- `CONTRIBUTING.md` — real `swift test --parallel --disable-swift-testing
  --xunit-output ...` + `reconcile-registry` commands
- `CODE_OF_CONDUCT.md` — Contributor Covenant 2.1, contact security@codeyam.com
- `SECURITY.md` — private reporting to security@codeyam.com
- `CHANGELOG.md` — Keep a Changelog, seeded Unreleased/initial-release entry
- `.github/ISSUE_TEMPLATE/` (bug_report, feature_request, config.yml),
  `.github/PULL_REQUEST_TEMPLATE.md`
- `.github/workflows/ci.yml` — Swift build + test; pinned to `macos-15`
  (Xcode 16 / Swift 6) because `--disable-swift-testing` requires Swift 6
- `README.md` — added Contributing + License sections (outside the
  codeyam-managed marker blocks)

## GitHub settings applied

- **Transfer:** jaredcosulich/codeyam-counter → codeyam-ai/codeyam-counter
- **Description:** "A native SwiftUI iOS counter app with a shared AppCore
  SwiftPM library — built and tested with codeyam-editor."
- **Topics:** swift, swiftui, ios, swiftpm, xctest, counter, codeyam, sample-app
- **Features:** Issues on, Discussions on, Wiki off
- **Visibility:** private → public
- **Branch protection (main):** require `Build & test` status check (strict),
  require PR with 1 approving review, dismiss stale reviews; `enforce_admins`
  off (admins retain direct control)

## Outstanding / waived

- **gitleaks false positives** in `.codeyam/.last-reconcile.json` will recur on
  every scan (the reconcile cache stores SHA-256 hashes). If CI ever adds secret
  scanning, add a gitleaks allowlist for that file to avoid noise.
- **`review-session` will keep reappearing on `init`** until the codeyam-editor
  fix ships (plan: `skills--stop-distributing-review-session-skill-to-clients`).
  It's gitignored here, so it won't re-enter git, but the on-disk copy returns.
- **GitHub license detection** flapped between `MIT` and `null` immediately after
  the visibility change (API eventual consistency); the LICENSE file is valid
  MIT and was detected. Re-check if it doesn't settle.
- **Backup:** pre-rewrite history saved at
  `/tmp/counter-backup-5710012.bundle` (local, ephemeral).
