// Riverpod providers for the Tölur sequencing activity. Phase 8 Plan 08-03.
//
// Mirrors Phase 5's matching_providers / Phase 6's cvc_providers shape:
// the round generator is materialized lazily and overridable in tests via
// `sequencingRoundGeneratorProvider.overrideWith((ref) => stubGen)`.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/numbers/sequencing_round.dart';

/// App-scoped seedable [SequencingRoundGenerator]. Default uses the
/// Random.secure-style timestamp seeding via `Random()` (no seed arg).
final sequencingRoundGeneratorProvider =
    Provider<SequencingRoundGenerator>(
  (ref) => SequencingRoundGenerator(),
);
