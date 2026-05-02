// Letter-to-Word Matching activity widget (Phase 5 Plan 05-02).
//
// Decisions exercised:
//   D-02   Standalone screen rendering one round at a time.
//   D-07   WRONG TAP IS SILENT (MATCH-02). The tile's intrinsic onTapDown
//          squeeze (Phase 4 LetterTile) is the SOLE feedback. NO audio.
//          NO state change. NO log. Pure no-op.
//   D-08   Correct tap (MATCH-03): plays the example-word audio as the
//          celebration cue (D-21 — no separate `narrationCelebrationCorrect`
//          clip in Phase 5) + shows MatchingCelebration overlay.
//   D-09   Auto-advance ~1.5s after correct tap (MatchingCelebration.duration).
//   D-14   Image fills upper 60% of screen (LayoutBuilder math); 4 tiles
//          in a row below.
//   D-15   Reuses LetterTile from Phase 4 directly. NO duplicate tile widget.
//   D-21   No `narrationCelebrationCorrect` clip; the example-word audio
//          serves double-duty as the celebration cue.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/alphabet/alphabet.dart';
import '../../../core/alphabet/icelandic_letter.dart';
import '../../../core/audio/audio_engine_provider.dart';
import '../../../core/matching/matching_round.dart';
import '../widgets/letter_tile.dart';
import 'matching_celebration.dart';
import 'matching_providers.dart';
import 'matching_round_image.dart';

class MatchingActivity extends ConsumerStatefulWidget {
  const MatchingActivity({super.key});

  @override
  ConsumerState<MatchingActivity> createState() => _MatchingActivityState();
}

class _MatchingActivityState extends ConsumerState<MatchingActivity> {
  MatchingRound? _currentRound;
  bool _celebrationVisible = false;
  Timer? _advanceTimer;

  @override
  void initState() {
    super.initState();
    // Schedule first round after first frame so ProviderScope is materialized.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _generateRound();
    });
  }

  void _generateRound() {
    final round = ref.read(roundGeneratorProvider).generate();
    setState(() {
      _currentRound = round;
      _celebrationVisible = false;
    });
  }

  void _onLetterTap(IcelandicLetter tapped) {
    final round = _currentRound;
    if (round == null) return;
    if (tapped != round.correctLetter) {
      // WRONG (D-07, MATCH-02): completely silent. The intrinsic LetterTile
      // squeeze animation is the sole feedback. Do nothing else.
      return;
    }
    // CORRECT (D-08, D-09, D-21): play target word as celebration cue,
    // show overlay, schedule auto-advance.
    unawaited(ref.read(audioEngineProvider).play(round.targetWordKey));
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
    final round = _currentRound;
    if (round == null) {
      // Pre-first-round empty state: blank surface + invisible celebration
      // (kept mounted so widget tests can find it from the start).
      return const Stack(
        children: <Widget>[
          SizedBox.expand(),
          MatchingCelebration(visible: false),
        ],
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final imageHeight = constraints.maxHeight * 0.60; // D-14
        return Stack(
          children: <Widget>[
            Column(
              children: <Widget>[
                SizedBox(
                  height: imageHeight,
                  child: MatchingRoundImage(round: round),
                ),
                const SizedBox(height: 16),
                Expanded(child: _buildOptionsRow(round)),
              ],
            ),
            MatchingCelebration(visible: _celebrationVisible),
          ],
        );
      },
    );
  }

  Widget _buildOptionsRow(MatchingRound round) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: <Widget>[
        for (final letter in round.options)
          SizedBox(
            width: 160,
            child: LetterTile(
              key: Key('matching-option-${letter.assetSlug}'),
              letter: letter,
              letterIndex: kIcelandicAlphabet.indexOf(letter),
              minSize: 0,
              onLetterTap: _onLetterTap,
            ),
          ),
      ],
    );
  }
}
