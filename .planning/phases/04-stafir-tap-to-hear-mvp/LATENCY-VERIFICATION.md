# STAFIR-02 Latency Verification — 240fps Camera Test

**Owner:** Jon
**Device under test:** Hugrún's actual tablet (note model + OS version)
**Acceptance:** PASS if median tap-to-audio-onset across 30 trials ≤ 50 ms; FAIL otherwise

## Why this is manual

Latency below ~50 ms cannot be measured reliably from inside the app — Flutter's frame timing reports >16 ms granularity in best case, and audio-onset timing requires physical observation of the speaker output. PITFALLS #4 + research Finding 4 explicitly call out 240fps camera as the only reliable measurement.

## Required equipment

1. Hugrún's tablet (production hardware — NOT simulator).
2. A second device that records video at 240 fps (recent iPhone via Camera app → "Slo-Mo" mode = 240fps; or any modern smartphone with a 240fps mode).
3. Tripod or steady surface for the camera.
4. The Hugrún app installed in release mode on the tablet (`flutter build apk --release` for Android; `flutter build ios --release` for iOS).

## Setup

1. Plug tablet in (avoid thermal throttling on a low-battery device).
2. Set tablet volume to ~50% (verify audio is audible).
3. Position tablet flat on a table; position the 240fps camera looking down on the screen so:
   - The full 32-letter grid is visible
   - The tester's finger is visible approaching the screen
4. Launch the Hugrún app fresh (kill any backgrounded copy first).
5. Wait 5 seconds after launch before the first tap (let warm-up complete + welcome narration finish).

## Procedure (10 trials per cold start)

1. Start 240fps recording.
2. Tap a letter — use the same letter (letterA) for consistency across trials.
3. Wait for the audio to finish.
4. Wait 2 seconds. Tap again. Repeat for 10 trials.
5. Stop recording. Repeat with a fresh app launch (kill + relaunch) twice more, for a total of 3 sessions × 10 trials = 30 measurements.

## Measurement

For each trial, in the 240fps video (4.17 ms per frame):

1. Identify the frame where the finger MAKES CONTACT with the screen (call it frame N_tap).
2. Identify the frame where the audio onset is visible/audible. Two methods:
   - **Audio waveform:** import the video into a video editor (DaVinci Resolve free; iMovie). The waveform shows audio onset precisely. Frame number at first audio sample > -40 dBFS = N_audio.
   - **Visual cue (less reliable):** the LetterTile scale animation begins at frame N_tap regardless of audio. Use audio-onset.
3. Latency = (N_audio - N_tap) × 4.17 ms.

Record each trial:

| Session | Trial | N_tap | N_audio | Latency (ms) | Pass (≤50)? |
|---------|-------|-------|---------|--------------|-------------|
| 1 | 1 | | | | |
| 1 | 2 | | | | |
| ... | ... | | | | |
| 3 | 10 | | | | |

## Pass criterion

- **PASS:** median of 30 trials ≤ 50 ms AND no trial > 100 ms (no outliers).
- **PASS WITH WARNING:** median ≤ 50 ms but ≥1 trial in [50, 100] ms — investigate (likely first-tap cold path; D-08 silence pad may be missing).
- **FAIL:** median > 50 ms — diagnose. Most likely causes:
  - Phase 3 silence-pad regression (D-08).
  - Warm pool not actually warming on this device (D-03).
  - Per-tap AudioPlayer creation slipped in (PITFALLS #4 #8).

## On FAIL

Open `.planning/phases/04-stafir-tap-to-hear-mvp/04-VERIFICATION.md` and document the failing trials. Run `/gsd-plan-phase 4 --gaps` to create a remediation plan.

## On PASS

Update `.planning/phases/04-stafir-tap-to-hear-mvp/04-VERIFICATION.md` STAFIR-02 row to:

```
PASSED ({median} ms median, {min}-{max} range, N=30, on {device} {OS})
```

## Quick reference — frame-to-ms

At 240 fps, 1 frame = 1000/240 ms ≈ 4.17 ms. Some useful conversions:

| Frames | ms (240fps) |
|--------|-------------|
| 1 | 4.17 |
| 4 | 16.7 |
| 8 | 33.3 |
| 12 | 50.0 |
| 16 | 66.7 |
| 24 | 100.0 |

50 ms ≈ 12 frames. If you can count more than 12 frames between finger-on-glass and audio-onset waveform, the test fails.
