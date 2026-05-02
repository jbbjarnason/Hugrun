// Riverpod providers for the One-to-One Correspondence activity (Phase 9
// Plan 09-01; NUM-04).
//
// Mirrors Phase 5 matching_providers / Phase 8 sequencing_providers shape:
// the round generator is materialized lazily and overridable in tests via
// `correspondenceRoundGeneratorProvider.overrideWith((ref) => stubGen)`.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/numbers/correspondence_round.dart';

/// App-scoped seedable [CorrespondenceRoundGenerator]. Default uses
/// timestamp-seeded `Random()` (no seed arg).
final correspondenceRoundGeneratorProvider =
    Provider<CorrespondenceRoundGenerator>(
  (ref) => CorrespondenceRoundGenerator(),
);
