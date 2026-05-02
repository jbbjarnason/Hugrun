// Plan 05-01 Task 1: MatchingRound value class tests.
//
// Verifies the pure-Dart round value object that the matching activity
// (Phase 5) consumes. See:
//   .planning/phases/05-letter-to-word-matching/05-CONTEXT.md (D-03..D-06, D-13)
//   .planning/phases/05-letter-to-word-matching/05-01-PLAN-round-generator.md
//
// MatchingRound is a Freezed value class with assertion-protected fields:
//   - options.length == 4
//   - no duplicate letters
//   - correctLetter is in options
//
// ImageSource is a sealed Freezed union with two cases:
//   - StockPlaceholder(wordSlug)  — Phase 5 default
//   - PhotoOverride(photoId)      — Phase 10 personalization slot (D-13)

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hugrun/core/alphabet/alphabet.dart';
import 'package:hugrun/core/alphabet/icelandic_letter.dart';
import 'package:hugrun/core/manifest/utterance_key.dart';
import 'package:hugrun/core/matching/matching_round.dart';

void main() {
  // Helpers — pick canonical letters from the alphabet by glyph.
  IcelandicLetter letterByGlyph(String glyph) =>
      kIcelandicAlphabet.firstWhere((l) => l.glyph == glyph);

  group('MatchingRound', () {
    test('Test 1: exposes the 5 documented fields with correct types', () {
      final h = letterByGlyph('h');
      final round = MatchingRound(
        targetWordKey: UtteranceKey.wordHundur,
        targetWordSlug: 'hundur',
        correctLetter: h,
        options: <IcelandicLetter>[
          h,
          letterByGlyph('b'),
          letterByGlyph('k'),
          letterByGlyph('s'),
        ],
        imageSource: const ImageSource.stockPlaceholder(wordSlug: 'hundur'),
      );

      expect(round.targetWordKey, UtteranceKey.wordHundur);
      expect(round.targetWordSlug, 'hundur');
      expect(round.correctLetter, h);
      expect(round.options, hasLength(4));
      expect(round.imageSource, isA<ImageSource>());
    });

    test('Test 2: throws AssertionError when correctLetter is not in options',
        () {
      final h = letterByGlyph('h');
      expect(
        () => MatchingRound(
          targetWordKey: UtteranceKey.wordHundur,
          targetWordSlug: 'hundur',
          correctLetter: h,
          options: <IcelandicLetter>[
            letterByGlyph('a'),
            letterByGlyph('b'),
            letterByGlyph('k'),
            letterByGlyph('s'),
          ],
          imageSource: const ImageSource.stockPlaceholder(wordSlug: 'hundur'),
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('Test 3: throws AssertionError when options length != 4', () {
      final h = letterByGlyph('h');
      expect(
        () => MatchingRound(
          targetWordKey: UtteranceKey.wordHundur,
          targetWordSlug: 'hundur',
          correctLetter: h,
          options: <IcelandicLetter>[h, letterByGlyph('b'), letterByGlyph('k')],
          imageSource: const ImageSource.stockPlaceholder(wordSlug: 'hundur'),
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('Test 4: throws AssertionError when options contain duplicates', () {
      final h = letterByGlyph('h');
      expect(
        () => MatchingRound(
          targetWordKey: UtteranceKey.wordHundur,
          targetWordSlug: 'hundur',
          correctLetter: h,
          options: <IcelandicLetter>[h, letterByGlyph('b'), letterByGlyph('b'),
            letterByGlyph('s')],
          imageSource: const ImageSource.stockPlaceholder(wordSlug: 'hundur'),
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('Test 5: equal MatchingRound instances have value equality + hash',
        () {
      final h = letterByGlyph('h');
      final options = <IcelandicLetter>[
        h,
        letterByGlyph('b'),
        letterByGlyph('k'),
        letterByGlyph('s'),
      ];
      final a = MatchingRound(
        targetWordKey: UtteranceKey.wordHundur,
        targetWordSlug: 'hundur',
        correctLetter: h,
        options: options,
        imageSource: const ImageSource.stockPlaceholder(wordSlug: 'hundur'),
      );
      final b = MatchingRound(
        targetWordKey: UtteranceKey.wordHundur,
        targetWordSlug: 'hundur',
        correctLetter: h,
        options: List<IcelandicLetter>.from(options),
        imageSource: const ImageSource.stockPlaceholder(wordSlug: 'hundur'),
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('Test 6: ImageSource union cases support value equality', () {
      const a = ImageSource.stockPlaceholder(wordSlug: 'hundur');
      const b = ImageSource.stockPlaceholder(wordSlug: 'hundur');
      expect(a, equals(b));

      const p1 = ImageSource.photoOverride(photoId: 'photo-uuid-1');
      const p2 = ImageSource.photoOverride(photoId: 'photo-uuid-1');
      expect(p1, equals(p2));

      expect(a, isNot(equals(p1)));
    });

    test(
      'Test 7: lib/core/matching/matching_round.dart contains no Flutter import',
      () {
        // Domain-purity invariant. The CI script tools/check-domain-purity.sh
        // includes lib/core/matching in its DOMAIN_PATHS list; this test gives
        // us a fast feedback loop if a Flutter import sneaks in via codegen
        // or a refactor.
        final file = File('lib/core/matching/matching_round.dart');
        expect(
          file.existsSync(),
          isTrue,
          reason: 'matching_round.dart must exist',
        );
        final source = file.readAsStringSync();
        expect(
          source.contains("import 'package:flutter/"),
          isFalse,
          reason: 'lib/core/matching/ is pure-Dart per D-05',
        );
      },
    );
  });
}
