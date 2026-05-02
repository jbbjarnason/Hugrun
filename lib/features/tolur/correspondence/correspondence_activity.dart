// One-to-One Correspondence activity (Phase 9 Plan 09-01; NUM-04).
//
// Decisions exercised:
//   D-01  Renders N copies of the noun image as tappable targets.
//   D-02  Picture-object counting uses GENDER of the depicted noun —
//         numberAudioKey(value, noun.gender) resolves the audio.
//   D-04  Tapping each in counting order: 1, 2, ..., count. Last narrated
//         number equals count (NUM-04).
//   D-05  Re-tapping a counted target is a no-op (no audio re-fire,
//         no state change).
//   D-13  Round complete = MatchingCelebration overlay + auto-advance
//         (mirrors Phase 5 MatchingActivity / Phase 8 SequencingActivity).
//   NUM-08  No fail state, no score, no timer.
//
// Layout: top half = the noun's image area (placeholder per Phase 5
// pattern when no image asset exists); bottom half = the N tappable
// targets in a Wrap. The placeholder layout is intentionally simple —
// Phase 10 swaps in personalized photos via the same imageSource
// abstraction once available.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/audio_engine_provider.dart';
import '../../../core/numbers/correspondence_round.dart';
import '../../../core/numbers/number_audio_resolver.dart';
import '../../stafir/matching/matching_celebration.dart';
import '../../stafir/widgets/letter_tile_palette.dart';
import 'correspondence_providers.dart';

class CorrespondenceActivity extends ConsumerStatefulWidget {
  const CorrespondenceActivity({super.key});

  @override
  ConsumerState<CorrespondenceActivity> createState() =>
      CorrespondenceActivityState();
}

class CorrespondenceActivityState
    extends ConsumerState<CorrespondenceActivity> {
  CorrespondenceRound? _round;

  /// Set of indices already tapped (counted). Re-tapping is a no-op.
  final Set<int> _counted = <int>{};

  /// Next expected count number — starts at 1 (D-04 first narration is
  /// "einn" / "ein" / "eitt"). Increments on each accepted tap.
  int _nextCount = 1;

  bool _celebrationVisible = false;
  Timer? _advanceTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _generateRound();
    });
  }

  void _generateRound() {
    final round = ref.read(correspondenceRoundGeneratorProvider).generate();
    setState(() {
      _round = round;
      _counted.clear();
      _nextCount = 1;
      _celebrationVisible = false;
    });
  }

  void _onTargetTap(int index) {
    final round = _round;
    if (round == null) return;
    // D-05: re-tap on already-counted target is a no-op.
    if (_counted.contains(index)) return;

    final key = numberAudioKey(_nextCount, round.noun.gender);
    unawaited(ref.read(audioEngineProvider).play(key));
    setState(() {
      _counted.add(index);
      _nextCount++;
    });

    if (_counted.length == round.tapTargets.length) {
      _showCelebrationAndAdvance();
    }
  }

  void _showCelebrationAndAdvance() {
    setState(() => _celebrationVisible = true);
    _advanceTimer?.cancel();
    _advanceTimer = Timer(MatchingCelebration.duration, () {
      if (!mounted) return;
      _generateRound();
    });
  }

  @override
  void dispose() {
    _advanceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final round = _round;
    if (round == null) {
      return const Stack(
        children: <Widget>[
          SizedBox.expand(),
          MatchingCelebration(visible: false),
        ],
      );
    }
    return Stack(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Wrap(
                alignment: WrapAlignment.center,
                runAlignment: WrapAlignment.center,
                spacing: 16,
                runSpacing: 16,
                children: <Widget>[
                  for (final t in round.tapTargets)
                    _CorrespondenceTarget(
                      key: Key('corr-target-${t.index}'),
                      index: t.index,
                      noun: round.noun,
                      counted: _counted.contains(t.index),
                      onTap: () => _onTargetTap(t.index),
                    ),
                ],
              );
            },
          ),
        ),
        MatchingCelebration(visible: _celebrationVisible),
      ],
    );
  }
}

class _CorrespondenceTarget extends StatelessWidget {
  const _CorrespondenceTarget({
    super.key,
    required this.index,
    required this.noun,
    required this.counted,
    required this.onTap,
  });

  final int index;
  final Noun noun;
  final bool counted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = paletteForIndex(index);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 160,
        height: 200,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(24),
          // Soft "counted" indicator — slightly faded, NO checkmark, NO score.
          // Visual feedback is intrinsic (alpha shift); no failure-state UI.
          border: counted
              ? Border.all(color: const Color(0xFF66BB6A), width: 4)
              : null,
        ),
        // Placeholder rendering: image asset may not exist yet (Phase 10
        // ships personalized photos; Phase 5 uses text-on-color
        // placeholders). errorBuilder falls back to the noun word.
        // Visual feedback for "counted" = green border on the AnimatedContainer
        // above. No check icon, no score, no number bubble — keeps the
        // surface clean per NUM-08.
        child: Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.asset(
              noun.imagePath,
              width: 140,
              height: 140,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) => SizedBox(
                width: 140,
                height: 140,
                child: Center(
                  child: Text(
                    noun.word,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
