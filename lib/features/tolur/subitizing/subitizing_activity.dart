// SubitizingActivity widget (Phase 9 Plan 09-02; NUM-05).
//
// Decisions exercised:
//   D-06  Round flashes 1..5 dots in varied arrangement, then asks the
//         child to tap the matching numeral from 5 options (1, 2, 3, 4, 5).
//   D-07  Arrangements rotate via the round generator (D-07 dot patterns).
//   D-08  Flash 1.5s default (kSubitizingFlashDuration).
//   D-09  Wrong tap = no-op (silent — same posture as Phase 5 D-07).
//         Correct tap = MatchingCelebration overlay + auto-advance.
//   NUM-08  No fail state, no score, no timer.
//
// Phases:
//   1. Flash phase (1.5s default): dots visible, numeral options hidden.
//   2. Question phase: dots hidden, 5 numeral options visible (1..5).
//   3. Celebration phase (1.5s default): MatchingCelebration overlay,
//      auto-advance to next round.
//
// No new manifest entries needed for Phase 9 (D-20). The numeral options'
// taps don't fire audio — the activity is silent except the celebration
// overlay's optional audio cue (omitted in Phase 9; can be added via
// existing keys later).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/numbers/subitizing_round.dart';
import '../../stafir/matching/matching_celebration.dart';
import '../../stafir/widgets/letter_tile_palette.dart';
import 'subitizing_providers.dart';

class SubitizingActivity extends ConsumerStatefulWidget {
  const SubitizingActivity({super.key});

  @override
  ConsumerState<SubitizingActivity> createState() => SubitizingActivityState();
}

enum _SubitizingPhase { flash, question, celebration }

class SubitizingActivityState extends ConsumerState<SubitizingActivity> {
  SubitizingRound? _round;
  _SubitizingPhase _phase = _SubitizingPhase.flash;
  Timer? _phaseTimer;
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
    final round = ref.read(subitizingRoundGeneratorProvider).generate();
    setState(() {
      _round = round;
      _phase = _SubitizingPhase.flash;
    });
    _phaseTimer?.cancel();
    _phaseTimer = Timer(kSubitizingFlashDuration, () {
      if (!mounted) return;
      setState(() => _phase = _SubitizingPhase.question);
    });
  }

  void _onOptionTap(int value) {
    final round = _round;
    if (round == null) return;
    if (_phase != _SubitizingPhase.question) return;
    if (value != round.count) {
      // D-09: wrong tap is silent. No state change, no audio, no celebration.
      return;
    }
    setState(() => _phase = _SubitizingPhase.celebration);
    _advanceTimer?.cancel();
    _advanceTimer = Timer(MatchingCelebration.duration, () {
      if (!mounted) return;
      _generateRound();
    });
  }

  @override
  void dispose() {
    _phaseTimer?.cancel();
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
        Column(
          children: <Widget>[
            // Top half: flash area or empty (after flash).
            Expanded(
              flex: 2,
              child: _phase == _SubitizingPhase.flash
                  ? _DotFlashArea(round: round)
                  : const SizedBox.shrink(),
            ),
            // Bottom half: numeral options when in question phase.
            Expanded(
              child: _phase == _SubitizingPhase.flash
                  ? const SizedBox.shrink()
                  : _NumeralOptionsRow(onTap: _onOptionTap),
            ),
          ],
        ),
        MatchingCelebration(visible: _phase == _SubitizingPhase.celebration),
      ],
    );
  }
}

class _DotFlashArea extends StatelessWidget {
  const _DotFlashArea({required this.round});

  final SubitizingRound round;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Center(
          child: Container(
            width: constraints.maxWidth * 0.7,
            height: constraints.maxHeight * 0.85,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E7),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Stack(
              key: const Key('sub-flash-area'),
              children: <Widget>[
                for (var i = 0; i < round.dotPositions.length; i++)
                  Positioned(
                    left:
                        round.dotPositions[i].x *
                        (constraints.maxWidth * 0.7 - 60),
                    top:
                        round.dotPositions[i].y *
                        (constraints.maxHeight * 0.85 - 60),
                    child: const _Dot(),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      height: 60,
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _NumeralOptionsRow extends StatelessWidget {
  const _NumeralOptionsRow({required this.onTap});

  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: <Widget>[
        for (var v = 1; v <= 5; v++)
          _NumeralOption(
            key: Key('sub-option-$v'),
            value: v,
            onTap: () => onTap(v),
          ),
      ],
    );
  }
}

class _NumeralOption extends StatelessWidget {
  const _NumeralOption({super.key, required this.value, required this.onTap});

  final int value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = paletteForIndex(value - 1);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 100,
        height: 140,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(24),
        ),
        alignment: Alignment.center,
        child: Text(
          '$value',
          style: const TextStyle(
            fontSize: 56,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
          ),
        ),
      ),
    );
  }
}
