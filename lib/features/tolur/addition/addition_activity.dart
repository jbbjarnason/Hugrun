// AdditionActivity widget (Phase 9 Plan 09-03; NUM-07).
//
// Decisions exercised:
//   D-10  Round narrates "[addend1] [noun-plural] koma. [addend2] [noun]
//         kemur til viðbótar." Two groups of objects appear; child taps
//         the answer numeral.
//   D-12  CRITICAL: NO `+` symbol anywhere in the widget tree. No add
//         icon, no plus glyph, no operator. Just two groups of objects.
//   D-13  Wrong tap = silent (consistent with subitizing D-09 / matching
//         D-07). Correct tap = MatchingCelebration overlay + auto-advance.
//   NUM-08  No fail state, no score, no timer.
//
// Layout:
//   - Top half: two horizontally-arranged groups of noun images. Group 1
//     has addend1 copies (left); group 2 has addend2 copies (right).
//     A subtle space separates them — no operator, no equals sign.
//   - Bottom half: 5 numeral options (1..5). Tapping the correct total
//     fires celebration; wrong is silent.
//
// Phase 9 ships using existing audio (CONTEXT D-20). The optional
// narration ("Tveir hundar koma. Einn hundur kemur til viðbótar.") is
// not pre-baked yet — we deliberately omit any audio cue on round entry
// per D-20's no-new-manifest constraint. The celebration overlay's
// visual feedback is the dominant cue.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/numbers/addition_round.dart';
import '../../../core/numbers/correspondence_round.dart';
import '../../stafir/matching/matching_celebration.dart';
import '../../stafir/widgets/letter_tile_palette.dart';
import 'addition_providers.dart';

class AdditionActivity extends ConsumerStatefulWidget {
  const AdditionActivity({super.key});

  @override
  ConsumerState<AdditionActivity> createState() => AdditionActivityState();
}

class AdditionActivityState extends ConsumerState<AdditionActivity> {
  AdditionRound? _round;
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
    final round = ref.read(additionRoundGeneratorProvider).generate();
    setState(() {
      _round = round;
      _celebrationVisible = false;
    });
  }

  void _onOptionTap(int value) {
    final round = _round;
    if (round == null) return;
    if (_celebrationVisible) return;
    if (value != round.totalValue) {
      // D-13: wrong tap is silent. No state change, no audio, no celebration.
      return;
    }
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
        Column(
          children: <Widget>[
            // Top half: two object groups (no operator between them).
            Expanded(flex: 2, child: _ObjectGroupsRow(round: round)),
            // Bottom half: 5 numeral options.
            Expanded(child: _NumeralOptionsRow(onTap: _onOptionTap)),
          ],
        ),
        MatchingCelebration(visible: _celebrationVisible),
      ],
    );
  }
}

class _ObjectGroupsRow extends StatelessWidget {
  const _ObjectGroupsRow({required this.round});

  final AdditionRound round;

  @override
  Widget build(BuildContext context) {
    // Two groups, each rendered as a Wrap. A SizedBox sits between them
    // — NOT a `+` symbol or any operator (D-12).
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: _ObjectGroup(
            count: round.addend1.value,
            noun: round.noun,
            keyPrefix: 'add-group1',
          ),
        ),
        const SizedBox(width: 32), // spacer, no glyph
        Expanded(
          child: _ObjectGroup(
            count: round.addend2.value,
            noun: round.noun,
            keyPrefix: 'add-group2',
          ),
        ),
      ],
    );
  }
}

class _ObjectGroup extends StatelessWidget {
  const _ObjectGroup({
    required this.count,
    required this.noun,
    required this.keyPrefix,
  });

  final int count;
  final Noun noun;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      runAlignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 12,
      children: <Widget>[
        for (var i = 0; i < count; i++)
          _NounImage(key: Key('$keyPrefix-$i'), index: i, noun: noun),
      ],
    );
  }
}

class _NounImage extends StatelessWidget {
  const _NounImage({super.key, required this.index, required this.noun});

  final int index;
  final Noun noun;

  @override
  Widget build(BuildContext context) {
    final color = paletteForIndex(index);
    return Container(
      width: 100,
      height: 130,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.asset(
            noun.imagePath,
            width: 90,
            height: 100,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stack) => SizedBox(
              width: 90,
              height: 100,
              child: Center(
                child: Text(
                  noun.word,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
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
            key: Key('add-option-$v'),
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
        height: 130,
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
