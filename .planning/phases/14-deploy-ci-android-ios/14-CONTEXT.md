---
phase: 14
title: Deploy CI for Android + iOS
status: passed
date: 2026-05-02
---

# Phase 14 — Deploy CI for Android + iOS

## Goal

Add GitHub Actions workflows that:

1. Build a release APK + AAB for Android on every push to `main`.
2. Build a release IPA for iOS (signed if secrets present, else unsigned)
   on every push to `main`.
3. Optionally deploy to Google Play Internal Testing (gated on
   `PLAY_SERVICE_ACCOUNT_JSON` secret).
4. Optionally deploy to TestFlight (gated on the five Apple-side secrets).
5. Skip deploy steps gracefully if secrets are absent — build artifacts
   should always upload regardless.

## Out of scope

- Setting up the actual store credentials (Apple Developer / Google Play
  Console). That is human-only paperwork and credential management.
  See `.planning/deployment/google-play-setup.md` for the runbook a
  browser-driving agent (or human) can follow to create the secrets.
- Deploying to user-visible release tracks (Play "production",
  TestFlight "external"). Phase 14 wires only `internal` / TestFlight
  internal as a safe default.

## Why now

End-of-v1.0 milestone: with content (audio, images, lexicon) frozen and
the kid surface stable (Phase 12), the next gate is "can a clean checkout
on a fresh runner produce a shippable artifact?" — that is the function
of Phase 14. Phase 15 is the operational follow-up that confirms the
workflows go green on the actual remote.
