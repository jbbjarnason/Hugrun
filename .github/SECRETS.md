# GitHub Actions Secrets — Hugrún

Until the secrets below are set in the repository, the **deploy steps are
gracefully skipped** — the build artifacts (APK, AAB, unsigned iOS .app) still
upload as workflow artifacts, so you always have something to inspect.

Set secrets at: <https://github.com/jbbjarnason/Hugrun/settings/secrets/actions>

## Required for Google Play deployment (Phase 14 deploy-android)

- `PLAY_SERVICE_ACCOUNT_JSON` — service account JSON key (full file contents,
  paste as plain text) from Google Play Console.
  Setup: Play Console → Setup → API Access → create service account, grant
  "Release manager" role on the app, download JSON key.
- `PLAY_PACKAGE_NAME` — `is.hugrun.app`

When both are set, the `deploy-android` workflow uploads the AAB to the Internal
Testing track via `r0adkll/upload-google-play@v1`.

## Required for TestFlight deployment (Phase 14 deploy-ios)

- `APP_STORE_CONNECT_API_KEY_ID` — App Store Connect API key ID (Users and
  Access → Integrations → App Store Connect API → Key ID)
- `APP_STORE_CONNECT_API_ISSUER_ID` — App Store Connect API issuer ID (same
  page; Issuer ID is global to the team)
- `APP_STORE_CONNECT_API_KEY` — App Store Connect API private key (the .p8
  file contents, paste as plain text including the BEGIN/END PRIVATE KEY lines)
- `IOS_BUILD_CERTIFICATE_BASE64` — distribution certificate exported from
  Keychain Access as .p12, then base64-encoded:
  `base64 -i Certificates.p12 | pbcopy`
- `IOS_P12_PASSWORD` — password used when exporting the .p12
- `IOS_PROVISIONING_PROFILE_BASE64` — App Store provisioning profile (.mobileprovision)
  for `is.hugrun.app`, base64-encoded:
  `base64 -i hugrun_AppStore.mobileprovision | pbcopy`
- `KEYCHAIN_PASSWORD` — any temporary password used by the runner to create
  a transient keychain (e.g. a long random string; not reused anywhere else)

When all are set, the `deploy-ios` workflow imports the cert, installs the
profile, builds a signed IPA, and uploads it to TestFlight via
`apple-actions/upload-testflight-build@v1`.

## Workflow behavior

| Scenario                                | deploy-android                          | deploy-ios                                              |
| --------------------------------------- | --------------------------------------- | ------------------------------------------------------- |
| No secrets                              | Builds APK + AAB; deploy step skipped   | Builds unsigned `.app`; TestFlight step skipped         |
| Play secrets only                       | Builds + uploads to Play Internal track | (unchanged — unsigned `.app` only)                      |
| iOS signing secrets only                | (unchanged — APK + AAB only)            | Builds signed IPA + uploads to TestFlight               |
| All secrets                             | Full Android deploy                     | Full iOS deploy                                         |

The artifact-only path is the default state of this repo; nothing breaks if
secrets are missing.
