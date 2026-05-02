// Pure-Dart domain model for one Icelandic numeral (1..10). Phase 8 D-07.
//
// Icelandic 1..4 declines for grammatical gender (masculine/feminine/neuter)
// — e.g. "einn hundur" (m) vs. "ein kona" (f) vs. "eitt hús" (n). 5..10
// does NOT decline (NUM-02 / D-04). The model carries up to four
// UtteranceKey references:
//
//   - [masculine]: M variant for 1..4 (null for 5..10)
//   - [feminine]:  F variant for 1..4 (null for 5..10)
//   - [neuter]:    N variant for 1..4 (null for 5..10)
//   - [invariant]: the single key used for abstract counting (D-08); for
//                  1..4 this equals [masculine] (NUM-03 school convention);
//                  for 5..10 this is the SOLE key.
//
// Pure Dart per Phase 8 D-04; tools/check-domain-purity.sh covers
// lib/core/numbers/.

import '../manifest/utterance_key.dart';

/// One Icelandic numeral entry (value 1..10) with its audio key bindings.
class IcelandicNumber {
  const IcelandicNumber({
    required this.value,
    this.masculine,
    this.feminine,
    this.neuter,
    required this.invariant,
  });

  /// 1..10. Validated by [kIcelandicNumbers] integrity tests.
  final int value;

  /// Masculine variant. Non-null for 1..4. For 5..10 this is null because
  /// numerals don't decline (NUM-02); use [invariant] instead.
  final UtteranceKey? masculine;

  /// Feminine variant. Non-null for 1..4. Null for 5..10 (NUM-02).
  final UtteranceKey? feminine;

  /// Neuter variant. Non-null for 1..4. Null for 5..10 (NUM-02).
  final UtteranceKey? neuter;

  /// The invariant audio key.
  ///
  /// - For 1..4: equals [masculine] — abstract counting uses M (D-08, NUM-03).
  /// - For 5..10: the sole numeral key.
  final UtteranceKey invariant;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IcelandicNumber &&
          runtimeType == other.runtimeType &&
          value == other.value &&
          masculine == other.masculine &&
          feminine == other.feminine &&
          neuter == other.neuter &&
          invariant == other.invariant;

  @override
  int get hashCode =>
      Object.hash(value, masculine, feminine, neuter, invariant);

  @override
  String toString() =>
      'IcelandicNumber(value=$value, m=$masculine, f=$feminine, '
      'n=$neuter, inv=$invariant)';
}
