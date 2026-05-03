// SequencingActivity widget — Tölur sequencing surface. Phase 8 Plan 08-03.
//
// Decisions exercised:
//   D-09  Standalone screen rendering one round at a time.
//   D-10  5 numerals; one optionally missing; others scrambled.
//   D-11  Two variants (Sort, FillMissing) — round generator picks ~50/50.
//   D-12  Drag-and-drop accepts ONLY the correct numeral; wrong drops
//         animate back to source and do NOT play audio.
//   D-13  Round complete = celebration overlay (reuses Phase 5's
//         MatchingCelebration) + auto-advance.
//   D-14  No fail state. No score. No timer.
//
// Layout (landscape):
//   - Top row: 5 target slots (DragTargets). For Sort variant: empty
//     slots; child fills all 5. For FillMissing: 4 already filled +
//     1 empty (missingPosition).
//   - Bottom row: source row of Draggables — the scrambled numerals the
//     child drags into the targets.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/numbers/sequencing_round.dart';
import '../../stafir/matching/matching_celebration.dart';
import '../../stafir/widgets/letter_tile_palette.dart';
import 'sequencing_providers.dart';

class SequencingActivity extends ConsumerStatefulWidget {
  const SequencingActivity({super.key});

  @override
  ConsumerState<SequencingActivity> createState() => SequencingActivityState();
}

/// Public so widget tests + integration tests can drive
/// [debugCompleteRound] / [debugRejectDrop] without simulating drag
/// gestures (which are flaky across DragTarget in widget-test mode).
/// The integration test exercises the real Draggable path against a
/// device binding.
class SequencingActivityState extends ConsumerState<SequencingActivity> {
  SequencingRound? _round;

  /// Map of targetSequence-index → numeral the child has placed there.
  /// Pre-populated for FillMissing variant (4 slots filled at start).
  /// Updated by accepted DragTarget drops.
  final Map<int, int> _filled = <int, int>{};

  /// Set of source values still available to drag. Removed when accepted
  /// into a target.
  final Set<int> _availableSources = <int>{};

  bool _celebrationVisible = false;
  Timer? _advanceTimer;

  /// D-12: counts wrong drops only for diagnostic purposes (NOT shown to
  /// the child). The integration / widget test asserts on stable invariants;
  /// this counter is kept private and never rendered.
  int _wrongDropCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _generateRound();
    });
  }

  void _generateRound() {
    final round = ref.read(sequencingRoundGeneratorProvider).generate();
    setState(() {
      _round = round;
      _celebrationVisible = false;
      _filled.clear();
      _availableSources.clear();
      if (round.isFillMissing) {
        // Pre-populate the 4 already-correct slots; the source row holds
        // only the single missing value (which the child drags into the
        // gap).
        for (var i = 0; i < round.targetSequence.length; i++) {
          if (i != round.missingPosition) {
            _filled[i] = round.targetSequence[i];
          }
        }
        _availableSources.add(round.missingValue);
      } else {
        // Sort variant: 5 source draggables (the scrambled list); all
        // 5 target slots empty.
        _availableSources.addAll(round.scrambledOrder);
      }
    });
  }

  bool _isComplete() {
    final round = _round;
    if (round == null) return false;
    if (_filled.length != round.targetSequence.length) return false;
    for (var i = 0; i < round.targetSequence.length; i++) {
      if (_filled[i] != round.targetSequence[i]) return false;
    }
    return true;
  }

  void _onAcceptDrop(int targetIndex, int draggedValue) {
    final round = _round;
    if (round == null) return;
    if (round.targetSequence[targetIndex] != draggedValue) {
      // D-12: wrong drop. Should be filtered by DragTarget.onWillAccept,
      // but defensive check in case onAcceptWithDetails fires anyway.
      _wrongDropCount++;
      return;
    }
    setState(() {
      _filled[targetIndex] = draggedValue;
      _availableSources.remove(draggedValue);
    });
    if (_isComplete()) {
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

  /// Test-only escape hatch (Plan 08-03 RED Q3, Q7). Drives the
  /// "round-complete" branch without simulating drags.
  @visibleForTesting
  void debugCompleteRound() {
    final round = _round;
    if (round == null) return;
    setState(() {
      _filled.clear();
      for (var i = 0; i < round.targetSequence.length; i++) {
        _filled[i] = round.targetSequence[i];
      }
      _availableSources.clear();
    });
    _showCelebrationAndAdvance();
  }

  /// Test-only escape hatch (Plan 08-03 RED Q5). Drives the wrong-drop
  /// silent-snap-back branch without simulating drags. Counts the rejection
  /// internally (no audio fired, no state mutated).
  @visibleForTesting
  void debugRejectDrop() {
    _wrongDropCount++;
  }

  @visibleForTesting
  int get debugWrongDropCount => _wrongDropCount;

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
            // Target row (top half).
            Expanded(
              child: _TargetRow(
                round: round,
                filled: _filled,
                onAccept: _onAcceptDrop,
                onReject: () => _wrongDropCount++,
              ),
            ),
            const SizedBox(height: 16),
            // Source row (bottom half).
            Expanded(
              child: _SourceRow(round: round, available: _availableSources),
            ),
          ],
        ),
        MatchingCelebration(visible: _celebrationVisible),
      ],
    );
  }
}

class _TargetRow extends StatelessWidget {
  const _TargetRow({
    required this.round,
    required this.filled,
    required this.onAccept,
    required this.onReject,
  });

  final SequencingRound round;
  final Map<int, int> filled;
  final void Function(int targetIndex, int draggedValue) onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: <Widget>[
        for (var i = 0; i < round.targetSequence.length; i++)
          _TargetSlot(
            key: Key('seq-target-$i'),
            targetIndex: i,
            expectedValue: round.targetSequence[i],
            filledValue: filled[i],
            onAccept: onAccept,
            onReject: onReject,
          ),
      ],
    );
  }
}

class _TargetSlot extends StatelessWidget {
  const _TargetSlot({
    super.key,
    required this.targetIndex,
    required this.expectedValue,
    required this.filledValue,
    required this.onAccept,
    required this.onReject,
  });

  final int targetIndex;
  final int expectedValue;
  final int? filledValue;
  final void Function(int, int) onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 160,
      child: DragTarget<int>(
        onWillAcceptWithDetails: (details) {
          if (filledValue != null) {
            // Slot already filled — soft reject.
            onReject();
            return false;
          }
          if (details.data != expectedValue) {
            onReject();
            return false;
          }
          return true;
        },
        onAcceptWithDetails: (details) => onAccept(targetIndex, details.data),
        builder: (context, candidate, rejected) {
          final filled = filledValue;
          final color = filled == null
              ? const Color(0xFFEDEDED) // empty slot
              : paletteForIndex(filled - 1);
          return Container(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(24),
              border: filled == null
                  ? Border.all(
                      color: const Color(0xFFBDBDBD),
                      width: 2,
                      style: BorderStyle.solid,
                    )
                  : null,
            ),
            alignment: Alignment.center,
            child: filled == null
                ? const SizedBox.shrink()
                : Text(
                    '$filled',
                    style: const TextStyle(
                      fontSize: 64,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
          );
        },
      ),
    );
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({required this.round, required this.available});

  final SequencingRound round;
  final Set<int> available;

  @override
  Widget build(BuildContext context) {
    // Render order: for Sort, use scrambledOrder (5 entries). For
    // FillMissing, the source row only ever contains the single missing
    // value, so just sort the available set.
    final ordered = round.isSort
        ? round.scrambledOrder
        : (available.toList()..sort());
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: <Widget>[
        for (final value in ordered)
          if (available.contains(value))
            _SourceChip(key: Key('seq-source-$value'), value: value)
          else
            const SizedBox(width: 100, height: 140),
      ],
    );
  }
}

class _SourceChip extends StatelessWidget {
  const _SourceChip({super.key, required this.value});

  final int value;

  @override
  Widget build(BuildContext context) {
    final color = paletteForIndex(value - 1);
    final tile = Container(
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
    );
    return Draggable<int>(
      data: value,
      feedback: Material(color: Colors.transparent, child: tile),
      childWhenDragging: Opacity(opacity: 0.3, child: tile),
      child: tile,
    );
  }
}
