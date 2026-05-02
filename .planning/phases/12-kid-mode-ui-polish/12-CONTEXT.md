---
phase: 12
title: Kid-Mode UI Polish
status: in-progress
date: 2026-05-02
---

# Phase 12 Context

Brief background captured from the orchestrator prompt + screenshot review.

## Problem

A UI screenshot review surfaced three high-priority visual issues in
the Hugrún kid-facing surfaces that violate PROJECT.md's "no text
instructions visible to child" / "discoverable through visuals and
audio alone" invariants:

1. Every kid-mode Scaffold shows an `AppBar` with a Text title
   ("Stafir", "Tölur", "Veldu orð") — a non-reader can't parse them
   and they take vertical real-estate from the activity surface.
2. The Stafir mode toggle uses 4 *different* icons, one per current
   mode (image, grid, spellcheck, edit). Inconsistent affordance:
   the icon shouldn't represent the current mode, it should
   represent "tap-and-hold to cycle".
3. Home-screen room buttons render as blank rounded rectangles
   captioned "Stafir" / "Tölur" — a pre-reader can't navigate.
4. The lexicon picker (parent settings) is a vertical text-only
   `ListView` of words. With Phase 11 stock images potentially
   landing in parallel, a 2-column image grid is more usable.

## Approach

Four parallel-safe workstreams under Phase 12's territory:

- **A.** Hide AppBar from kid-facing screens (StafirRoom + TolurRoom
  containers). Activities (Matching/CVC/Tracing/Sequencing/...) are
  hosted inside those rooms and have no AppBars of their own.
  Update widget tests that asserted AppBar presence.
- **B.** Replace mode-toggle icons with one consistent
  cycle icon (`Icons.swap_horiz`) for both StafirModeToggle and
  TolurModeToggle. The hold-ring affordance (already present, reused
  from ParentGateController) is the "hold to switch" hint.
- **C.** Home screen `RoomButton` renders a styled glyph (alphabet
  motif "Aa á" for Stafir, numeral motif "1 2 3" for Tölur) above
  the smaller text label. Tap behavior unchanged.
- **D.** Lexicon picker rebuilt as a 2-column image grid; tile shows
  the lexicon entry's `defaultImagePath` with a graceful
  `errorBuilder` text fallback when the image is missing
  (Phase 11 may or may not have shipped).

## Out of scope

- `assets/images/` — owned by Phase 11.
- `tools/tts/` and `lib/gen/audio_manifest.g.dart` — owned by
  Phase 13.
- Parent-facing screens keep their AppBars (parent reads them).

## Constraints inherited

- TDD red→green→refactor with atomic commits (one task = one
  RED commit + one GREEN commit at minimum).
- No new banned packages.
- Reuse `ParentGateController` for hold-to-switch.
- Don't break the home screen's 3-second-hold parent gate (cog icon).
