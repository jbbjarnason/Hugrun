// Resolves (value, gender) → UtteranceKey for Icelandic numerals. Phase 8 D-08.
//
// Behavior:
//   - 1..4 with Gender.masculine → masculine variant
//   - 1..4 with Gender.feminine  → feminine variant
//   - 1..4 with Gender.neuter    → neuter variant
//   - 5..10 with any gender      → invariant (NUM-02 — 5+ does not decline)
//
// Throws RangeError for value outside 1..10. Callers (Tölur tap-to-hear,
// sequencing activity, future NUM-04..NUM-07) validate inputs upstream;
// this is a defensive throw so a typo doesn't silently misroute audio.
//
// Pure Dart per Phase 8 D-04.

import '../manifest/utterance_key.dart';
import 'gender.dart';
import 'numbers.dart';

/// Returns the [UtteranceKey] for the given numeral [value] and grammatical
/// [gender].
///
/// For abstract counting (Tölur tap-to-hear, sequencing) callers pass
/// [Gender.masculine] per NUM-03 / D-03 (school convention). Phase 9
/// (picture-object counting) will pass the depicted noun's gender.
UtteranceKey numberAudioKey(int value, Gender gender) {
  if (value < 1 || value > 10) {
    throw RangeError.range(value, 1, 10, 'value',
        'numberAudioKey: value must be 1..10');
  }
  final entry = kIcelandicNumbers[value - 1];
  if (value >= 5) {
    // 5..10 do NOT decline (NUM-02): same key for any gender input.
    return entry.invariant;
  }
  // 1..4 decline. Resolver fields are non-null for 1..4 by kIcelandicNumbers
  // construction (asserted by tests K2 + K6); we read non-null here.
  switch (gender) {
    case Gender.masculine:
      return entry.masculine!;
    case Gender.feminine:
      return entry.feminine!;
    case Gender.neuter:
      return entry.neuter!;
  }
}
