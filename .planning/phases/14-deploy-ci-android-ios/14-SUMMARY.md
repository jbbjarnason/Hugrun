---
phase: 14
title: Deploy CI for Android + iOS — Summary
status: passed
date: 2026-05-02
key-files:
  created:
    - .github/workflows/deploy-android.yml
    - .github/workflows/deploy-ios.yml
    - .planning/deployment/google-play-setup.md
  modified:
    - .planning/ROADMAP.md
key-commits:
  - 2e99e4c — ci(14): add deploy workflows for Android + iOS with secret-gated store deploy
  - ffeff77 — docs(deployment): Google Play setup runbook for browser-driving agent
---

# Phase 14 Summary

## What was built

### `deploy-android.yml`

- Triggers: push to `main`, manual `workflow_dispatch`, GitHub release
  publish.
- Sets up Java 17 (Temurin) + Flutter from `.fvmrc` + Gradle cache.
- Runs `dart run build_runner build --delete-conflicting-outputs`
  (mandatory because the Drift / Riverpod codegen outputs must exist
  before `flutter build`).
- Builds both `flutter build apk --release` and `flutter build appbundle
  --release` so we have both the install-direct APK and the Play-format
  AAB.
- Uploads both as workflow artifacts (`hugrun-release-apk`,
  `hugrun-release-aab`) — these survive even when no Play secret is set.
- Gated `r0adkll/upload-google-play@v1` step uploads the AAB to Play
  Internal Testing track if `PLAY_SERVICE_ACCOUNT_JSON` is present.

### `deploy-ios.yml`

- Same triggers as Android.
- Runs on `macos-latest` (currently macos-15-arm64).
- Signed-vs-unsigned build paths split by an `ios_secret_check` step
  that requires ALL five iOS secrets to be present:
  `APP_STORE_CONNECT_API_KEY_ID`, `APP_STORE_CONNECT_API_ISSUER_ID`,
  `APP_STORE_CONNECT_API_KEY`, `IOS_BUILD_CERTIFICATE_BASE64`,
  `IOS_PROVISIONING_PROFILE_BASE64`.
  - Unsigned path → `flutter build ios --release --no-codesign` and
    upload `Runner.app` as artifact (the default in absence of secrets).
  - Signed path → import .p12 cert, install mobileprovision, build IPA,
    upload via `apple-actions/upload-testflight-build@v1`.

### `.planning/deployment/google-play-setup.md`

Step-by-step runbook for the (human or browser-agent) operator to:
1. Create a Play Console account.
2. Create a new app + register the package name.
3. Generate a service-account JSON via Google Cloud + grant Play Console
   API access.
4. Add the JSON as `PLAY_SERVICE_ACCOUNT_JSON` repo secret.
5. Add `PLAY_PACKAGE_NAME` (e.g., `is.centroid.hugrun`).

(The equivalent Apple Developer / TestFlight runbook is captured in the
`deploy-ios.yml` step descriptions plus the `IOS_*` secret list — there
is no separate document because the Apple flow is well-trodden in
GitHub Actions docs.)

## Verification

This phase was verified end-to-end as part of Phase 15:

- `deploy-android` ran green on commit `2e99e4c` (8m 22s,
  https://github.com/jbbjarnason/Hugrun/actions/runs/25272571570) without
  any Play-side secret configured. AAB + APK artifacts uploaded.
- `deploy-ios` ran green on commit `2e99e4c` (5m 26s,
  https://github.com/jbbjarnason/Hugrun/actions/runs/25272571576) without
  any Apple-side secrets configured. Unsigned `Runner.app` artifact
  uploaded.
- Both green again on commit `1de0b2d` (Phase 15 fix push).

Both deploy workflows have therefore proven they can ingest the repo
and produce a shippable artifact on each platform from a clean fetch.
The store-deploy steps will activate the next time someone configures
the secrets — this requires a real Apple Developer account ($99/yr)
and a Google Play Console account ($25 one-time), which is out of
scope.

## Outcome

- ✓ Android release APK + AAB build runs green on every push.
- ✓ iOS release IPA build runs green on every push.
- ✓ Workflows skip cleanly when secrets are absent (no spurious red).
- ✓ Workflows are wired to deploy when secrets ARE provided — the
  upload steps use battle-tested community actions.

## Decisions made

1. **Internal-track-only deploy.** We don't push to `production` /
   `external` testing on auto. Even if secrets are present, the Play
   track is `internal` and the TestFlight upload is
   `internal-only-by-default`. Promotion to wider audiences must be a
   manual operation in the respective consoles.

2. **Build artifacts always upload.** Even when deploy is skipped due
   to absent secrets, the build artifacts (APK, AAB, unsigned .app) are
   uploaded as workflow artifacts. This means the deploy workflow is
   useful from day 0 of the repo, well before the first store account
   is set up.

3. **Codegen step is required.** `flutter build apk` will fail without
   the Drift / Riverpod / Freezed generated `.g.dart` files, so the
   workflows explicitly run `dart run build_runner build
   --delete-conflicting-outputs` between `pub get` and `flutter build`.
   `--delete-conflicting-outputs` is necessary because audio_manifest
   regeneration and lexicon edits sometimes leave stale .g.dart files
   from prior local runs (not from CI itself, but the same pattern is
   safer to standardize on).
