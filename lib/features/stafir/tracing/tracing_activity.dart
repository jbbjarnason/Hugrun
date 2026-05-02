// Phase 7 letter-tracing activity (TRACE-01..05).
//
// Composes the stroke_order_animator package's StrokeOrderAnimator
// widget for the currently-active letter. On round-complete it fires
// celebration audio via AudioEngine and auto-advances to a new random
// letter. No fail state, no timer, no progress UI (TRACE-03/04;
// STAFIR-07/08 spirit).
//
// Decisions exercised:
//   D-07 — TracingActivity composes the package's animator + room
//          chrome; no custom CustomPainter.
//   D-08 — Renders the animator at center of viewport.
//   D-09 — No round counter, no progress UI, no fail state. Soft order
//          via the package's hintAfterStrokes default.
//   D-10 — Completion fires celebration narration (D-14 fallback);
//          activity auto-advances to a new letter.
//   D-11/D-12 — Tolerance values left at package defaults; tunable
//          per Hugrún at the tablet (LetterTracingPolicy const).
//   D-13 — No per-stroke audio (visual completion is enough); only
//          round-complete plays audio.
//   D-14 — narrationCelebrationTracing preferred; soft fallback to
//          narrationWelcome.
//
// Riverpod scoping:
//   audioEngineProvider     — app-scoped, never disposed per-tap (D-01).
//   traceDataProvider       — Future<Map<Letter, Glyph>>; tests override
//                             with Future.value(fixture).
//   tracingCurrentLetterProvider — Notifier wrapping the active letter;
//                             auto-advance writes a new value on completion.

import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stroke_order_animator/stroke_order_animator.dart';

import '../../../core/alphabet/icelandic_letter.dart';
import '../../../core/audio/audio_engine_provider.dart';
import '../../../core/tracing/glyph_loader.dart';
import 'trace_data_provider.dart';
import 'tracing_celebration.dart';

/// Calibration constants — tracing tolerance and visual width.
///
/// D-11 / D-12 / TRACE-02:
///   - `brushWidth`: the chunky-crayon stroke render width (logical px
///     in package canvas space; the animator scales to viewport).
///   - `hintAfterStrokes`: number of wrong strokes before the package
///     plays its animated hint. Default 3; we relax to 5 for first-
///     session calibration (5yo motor input, PITFALLS §3).
///
/// These are user-tunable constants, NOT magic numbers — Hugrún's tablet
/// session calibrates them. Phase 7 ships the defaults; the calibration
/// sign-off is the manual-verify checkpoint at phase close
/// (07-VERIFICATION.md).
class LetterTracingPolicy {
  const LetterTracingPolicy({
    this.brushWidth = 18.0,
    this.hintAfterStrokes = 5,
    this.autoAdvanceDelay = const Duration(milliseconds: 1200),
  });

  final double brushWidth;
  final int hintAfterStrokes;
  final Duration autoAdvanceDelay;
}

/// The default tracing policy. Override in tests if a faster
/// auto-advance is needed. Currently kid-friendly defaults from
/// PITFALLS §3 + research § Pitfall 3.
const LetterTracingPolicy kDefaultTracingPolicy = LetterTracingPolicy();

/// Phase 7 letter-tracing activity.
///
/// Composes the stroke_order_animator package's `StrokeOrderAnimator`
/// for the currently-selected letter. Wires `onQuizCompleteCallback`
/// to AudioEngine (celebration narration) + auto-advance to a new
/// random letter. Soft stroke-order via the package's defaults.
class TracingActivity extends ConsumerStatefulWidget {
  const TracingActivity({super.key, this.policy = kDefaultTracingPolicy});

  final LetterTracingPolicy policy;

  @override
  ConsumerState<TracingActivity> createState() => TracingActivityState();
}

/// Public so widget tests can drive `debugCompleteForTesting` and
/// `debugWrongStrokeForTesting`.
class TracingActivityState extends ConsumerState<TracingActivity>
    with TickerProviderStateMixin {
  StrokeOrderAnimationController? _controller;

  /// The letter currently being constructed/tracked. Mirrors the value
  /// in `tracingCurrentLetterProvider` but cached so we can detect
  /// changes (e.g. via override in tests) and rebuild the controller.
  IcelandicLetter? _activeLetter;

  /// Cached glyph for the active letter, pulled from `traceDataProvider`.
  TraceGlyph? _activeGlyph;

  Timer? _advanceTimer;

  /// Test-only: the letter currently rendered.
  @visibleForTesting
  IcelandicLetter? get debugCurrentLetter => _activeLetter;

  /// Test-only: simulate quiz completion (the package controller's
  /// internal `notifyQuizCompleteCallbacks` is private). We re-implement
  /// the control flow at this layer: fire the celebration callback,
  /// schedule the auto-advance.
  @visibleForTesting
  void debugCompleteForTesting() => _onQuizComplete();

  /// Test-only: simulate a wrong-stroke event. The activity treats
  /// wrong strokes as no-ops at the audio/UI level. We expose this
  /// hook so tests can assert "wrong stroke does NOT fire celebration".
  @visibleForTesting
  void debugWrongStrokeForTesting() {
    // Intentional no-op at the activity layer: TRACE-03 says wrong
    // strokes never produce a fail signal. The package's internal
    // mistake counter advances; the animator's CustomPainter draws
    // the hint after N misses. NOTHING happens here.
  }

  @override
  void initState() {
    super.initState();
    // Initial letter: read once. Subsequent advances happen via the
    // notifier (.set) inside _onQuizComplete.
    _activeLetter = ref.read(tracingCurrentLetterProvider);
  }

  @override
  void dispose() {
    _advanceTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  void _ensureController() {
    final letter = _activeLetter;
    if (letter == null) return;
    final glyph = _activeGlyph;
    if (glyph == null) return;
    // (Re)build the controller bound to the active glyph.
    _controller?.dispose();
    final c = StrokeOrderAnimationController(
      StrokeOrder(glyph.rawJson),
      this,
      brushWidth: widget.policy.brushWidth,
      hintAfterStrokes: widget.policy.hintAfterStrokes,
      onQuizCompleteCallback: (_) => _onQuizComplete(),
    );
    c.startQuiz();
    _controller = c;
  }

  void _onQuizComplete() {
    final engine = ref.read(audioEngineProvider);
    final key = selectCelebrationKey();
    unawaited(engine.play(key));
    // Auto-advance after a short delay so the celebration audio has a
    // moment to start playing. We bias against re-rolling the same
    // letter (UX nicety — kids notice if it never changes).
    _advanceTimer?.cancel();
    _advanceTimer = Timer(widget.policy.autoAdvanceDelay, () {
      if (!mounted) return;
      final next = pickDifferentLetter(_activeLetter, Random());
      ref.read(tracingCurrentLetterProvider.notifier).set(next);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Watch the current-letter provider so the activity rebuilds on
    // auto-advance and on test-time overrides.
    final providerLetter = ref.watch(tracingCurrentLetterProvider);
    if (providerLetter != _activeLetter) {
      _activeLetter = providerLetter;
      _activeGlyph = null;
    }

    final letter = _activeLetter!;
    // Watch the async map. tests pre-resolve via Future.value(fixture).
    final asyncMap = ref.watch(traceDataProvider);
    return asyncMap.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => const SizedBox.shrink(),
      data: (cache) {
        final glyph = cache[letter];
        if (glyph == null) {
          // Asset is missing — should not happen in practice (the map
          // is fully loaded). Render empty rather than crash.
          return const SizedBox.shrink();
        }
        if (glyph != _activeGlyph) {
          _activeGlyph = glyph;
          // Schedule controller (re)build after this frame.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _ensureController();
            if (mounted) setState(() {});
          });
        }
        final controller = _controller;
        return RepaintBoundary(
          child: Center(
            child: SizedBox(
              width: 600,
              height: 600,
              child: controller != null
                  ? StrokeOrderAnimator(
                      controller,
                      key: ValueKey<String>(letter.assetSlug),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        );
      },
    );
  }
}
