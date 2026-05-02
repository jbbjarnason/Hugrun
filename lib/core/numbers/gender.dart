// Pure-Dart grammatical-gender enum for Icelandic numerals. Phase 8 D-08.
//
// Used by [numberAudioKey] to resolve the right UtteranceKey for a digit:
//   - Abstract counting (Tölur tap-to-hear, sequencing) uses Gender.masculine
//     per NUM-03 / D-03 (school convention).
//   - Picture-object counting (Phase 9) will pass the depicted noun's gender.
//
// 5..10 do NOT decline in Icelandic (NUM-02): the resolver returns the same
// invariant key for any Gender input.
//
// Pure Dart — see Phase 8 D-04 (lib/core/numbers/ stays Flutter-free; the
// allow-list in tools/check-domain-purity.sh is extended).

enum Gender { masculine, feminine, neuter }
