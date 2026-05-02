// Canonical 10-entry Icelandic numeral list. Phase 8 D-07; NUM-01.
//
// Order: 1..10 in ascending order. The Tölur tap-to-hear grid renders this
// list in order (digits 1..10, two rows × five columns landscape per D-01).
// The sequencing activity (D-09..D-14) draws from this list as well.
//
// 1..4 ship with all three gender variants populated; invariant equals
// masculine (D-08 — abstract counting uses M, NUM-03). 5..10 ship with
// only [invariant] populated since Icelandic numerals 5+ do not decline
// for gender (NUM-02 / D-04).
//
// Pure Dart per Phase 8 D-04.

import '../manifest/utterance_key.dart';
import 'icelandic_number.dart';

/// The 10 Icelandic numerals 1..10 with their audio key bindings.
const List<IcelandicNumber> kIcelandicNumbers = <IcelandicNumber>[
  // 1..4: gendered (NUM-02)
  IcelandicNumber(
    value: 1,
    masculine: UtteranceKey.numberOneMasc,
    feminine: UtteranceKey.numberOneFem,
    neuter: UtteranceKey.numberOneNeut,
    invariant: UtteranceKey.numberOneMasc,
  ),
  IcelandicNumber(
    value: 2,
    masculine: UtteranceKey.numberTwoMasc,
    feminine: UtteranceKey.numberTwoFem,
    neuter: UtteranceKey.numberTwoNeut,
    invariant: UtteranceKey.numberTwoMasc,
  ),
  IcelandicNumber(
    value: 3,
    masculine: UtteranceKey.numberThreeMasc,
    feminine: UtteranceKey.numberThreeFem,
    neuter: UtteranceKey.numberThreeNeut,
    invariant: UtteranceKey.numberThreeMasc,
  ),
  IcelandicNumber(
    value: 4,
    masculine: UtteranceKey.numberFourMasc,
    feminine: UtteranceKey.numberFourFem,
    neuter: UtteranceKey.numberFourNeut,
    invariant: UtteranceKey.numberFourMasc,
  ),
  // 5..10: invariant only (NUM-02)
  IcelandicNumber(value: 5, invariant: UtteranceKey.numberFive),
  IcelandicNumber(value: 6, invariant: UtteranceKey.numberSix),
  IcelandicNumber(value: 7, invariant: UtteranceKey.numberSeven),
  IcelandicNumber(value: 8, invariant: UtteranceKey.numberEight),
  IcelandicNumber(value: 9, invariant: UtteranceKey.numberNine),
  IcelandicNumber(value: 10, invariant: UtteranceKey.numberTen),
];
