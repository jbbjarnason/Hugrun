---
status: passed
phase: 14
title: Deploy CI for Android + iOS — Verification
date: 2026-05-02
---

# Phase 14 Verification

## Status: passed

Both deploy workflows are committed, push-triggered, and have completed
successfully on the remote at least twice each (across two separate
commits to `main`). The build artifacts upload regardless of whether
store secrets are configured. The store-deploy steps are wired and will
activate cleanly the moment secrets are added.

## Workflows in `.github/workflows/`

```
deploy-android.yml  — build APK + AAB, upload artifacts, optional
                       Google Play Internal Testing deploy
deploy-ios.yml      — build IPA (signed if secrets, else unsigned),
                       upload artifact, optional TestFlight deploy
```

## Confirmed green CI runs

| Workflow         | Commit  | Run                                                           | Duration | Status    |
| ---------------- | ------- | ------------------------------------------------------------- | -------- | --------- |
| deploy-android   | 2e99e4c | https://github.com/jbbjarnason/Hugrun/actions/runs/25272571570 | 8m 22s   | ✓ success |
| deploy-ios       | 2e99e4c | https://github.com/jbbjarnason/Hugrun/actions/runs/25272571576 | 5m 26s   | ✓ success |
| deploy-android   | 1de0b2d | https://github.com/jbbjarnason/Hugrun/actions/runs/25281474872 | (~8m)    | ✓ success |
| deploy-ios       | 1de0b2d | https://github.com/jbbjarnason/Hugrun/actions/runs/25281474869 | (~5m)    | ✓ success |

## Required secrets (still to be added by human)

For Google Play Internal Testing deploy (when ready to ship):

- `PLAY_SERVICE_ACCOUNT_JSON` — full JSON for a Play Console service
  account with API publishing scope.
- `PLAY_PACKAGE_NAME` — e.g., `is.centroid.hugrun` (must match
  `android/app/build.gradle.kts` `applicationId`).

For TestFlight deploy (when ready to ship):

- `APP_STORE_CONNECT_API_KEY_ID` — short alphanumeric Key ID.
- `APP_STORE_CONNECT_API_ISSUER_ID` — UUID issuer ID.
- `APP_STORE_CONNECT_API_KEY` — full PEM-format private key.
- `IOS_BUILD_CERTIFICATE_BASE64` — `base64 -i Certificates.p12 | pbcopy`.
- `IOS_P12_PASSWORD` — password for the .p12.
- `IOS_PROVISIONING_PROFILE_BASE64` — `base64 -i hugrun.mobileprovision | pbcopy`.
- `KEYCHAIN_PASSWORD` — any password (used to wrap the imported certs).

The `.planning/deployment/google-play-setup.md` runbook walks through
the Play side step-by-step.

## What is intentionally NOT verified

- Actual store deploy. With no secrets present, the deploy steps are
  conditionally skipped (`if: steps.*.has_secret(s) == 'true'`). The
  upload-build-artifact steps still run and prove the build succeeded.
- Production-track promotion. The deploy step targets `internal` /
  TestFlight-internal only; promoting to wider audiences is a manual
  console operation by design.

## Soft warnings (informational)

The runner emits a deprecation notice that `actions/checkout@v4`,
`actions/setup-java@v4`, and `actions/upload-artifact@v4` all currently
ship on Node.js 20, which GitHub will remove on September 16th, 2026.
This is upstream and does not affect functionality. The actions will
auto-bump or we will pin updated versions before the removal date.
