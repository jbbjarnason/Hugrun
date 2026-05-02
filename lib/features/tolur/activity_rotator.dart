// ActivityRotator — Tölur Activity-mode shuffle host (Phase 9 D-15).
//
// Decisions exercised:
//   D-15  Tölur Activity mode rotates between 4 numeracy activities each
//         round. Sequence, Correspondence, Subitizing, Addition each
//         have an equal probability (random uniform).
//   D-16  Random rotation. Each round in the active widget completes,
//         the activity itself auto-advances internally; the rotator only
//         picks the *initial* widget per mount + can be advanced via
//         debugAdvance for tests.
//
// Why a single rotator instead of switching activities round-by-round?
//   - Each activity widget owns its own round-generation lifecycle and
//     auto-advance Timer (Phase 5/8 pattern). Re-mounting between rounds
//     would interrupt the activity's local state and cause flicker.
//   - The kid sees variety because the rotator picks a different
//     activity each time the parent toggles in/out of Activity mode.
//   - For mid-session variety, a future polish pass can wire a
//     "completed N rounds → swap" trigger in TolurRoom; out of scope
//     for Phase 9.
//
// Test affordances: `seed` makes the initial activity choice deterministic;
// `debugAdvance()` advances to the next activity for the rotator test.

import 'dart:math';

import 'package:flutter/material.dart';

import 'addition/addition_activity.dart';
import 'correspondence/correspondence_activity.dart';
import 'sequencing/sequencing_activity.dart';
import 'subitizing/subitizing_activity.dart';

/// The set of activities in the rotation.
enum TolurActivity { sequence, correspondence, subitizing, addition }

class ActivityRotator extends StatefulWidget {
  const ActivityRotator({super.key, this.seed});

  /// Optional Random seed. When provided, the initial activity choice
  /// is deterministic (used by tests). In production callers leave it
  /// null so each mount picks a fresh random activity.
  final int? seed;

  @override
  State<ActivityRotator> createState() => ActivityRotatorState();
}

/// Public so widget tests can inspect [debugCurrent] and call
/// [debugAdvance] without driving real round completions.
class ActivityRotatorState extends State<ActivityRotator> {
  late final Random _rng = widget.seed != null
      ? Random(widget.seed)
      : Random();
  late TolurActivity _current;

  @override
  void initState() {
    super.initState();
    _current = _pick();
  }

  TolurActivity _pick() {
    const values = TolurActivity.values;
    return values[_rng.nextInt(values.length)];
  }

  @visibleForTesting
  TolurActivity get debugCurrent => _current;

  @visibleForTesting
  void debugAdvance() {
    setState(() => _current = _pick());
  }

  @override
  Widget build(BuildContext context) {
    switch (_current) {
      case TolurActivity.sequence:
        return const SequencingActivity();
      case TolurActivity.correspondence:
        return const CorrespondenceActivity();
      case TolurActivity.subitizing:
        return const SubitizingActivity();
      case TolurActivity.addition:
        return const AdditionActivity();
    }
  }
}
