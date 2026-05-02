// Riverpod providers for the Subitizing activity (Phase 9 Plan 09-02; NUM-05).
//
// Mirrors Phase 5/8 provider patterns: the round generator is materialized
// lazily and overridable in tests via
// `subitizingRoundGeneratorProvider.overrideWith((ref) => stubGen)`.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/numbers/subitizing_round.dart';

/// App-scoped seedable [SubitizingRoundGenerator]. Default uses
/// timestamp-seeded `Random()` (no seed arg).
final subitizingRoundGeneratorProvider =
    Provider<SubitizingRoundGenerator>(
  (ref) => SubitizingRoundGenerator(),
);
