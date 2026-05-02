// Riverpod providers for the Addition activity (Phase 9 Plan 09-03; NUM-07).
//
// Mirrors Phase 5/8/9-correspondence/9-subitizing patterns: round generator
// is materialized lazily and overridable in tests via
// `additionRoundGeneratorProvider.overrideWith((ref) => stubGen)`.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/numbers/addition_round.dart';

/// App-scoped seedable [AdditionRoundGenerator]. Default uses
/// timestamp-seeded `Random()` (no seed arg).
final additionRoundGeneratorProvider = Provider<AdditionRoundGenerator>(
  (ref) => AdditionRoundGenerator(),
);
