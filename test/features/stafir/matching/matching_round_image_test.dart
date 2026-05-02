// Plan 05-02 Task 1 tests: MatchingRoundImage widget + Riverpod providers.
//
// Covers:
//   - Provider defaults (P1, P2)
//   - StockPlaceholder rendering (I1)
//   - PhotoOverride rendering (I2 — placeholder until Phase 10)
//   - Layout in a constrained box (I3)
//   - No instructional/score/timer text (I4)

// ignore_for_file: scoped_providers_should_specify_dependencies

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugrun/core/alphabet/alphabet.dart';
import 'package:hugrun/core/manifest/utterance_key.dart';
import 'package:hugrun/core/matching/matching_round.dart';
import 'package:hugrun/core/matching/photo_override_source.dart';
import 'package:hugrun/core/matching/round_generator.dart';
import 'package:hugrun/features/stafir/matching/matching_providers.dart';
import 'package:hugrun/features/stafir/matching/matching_round_image.dart';

MatchingRound _stockRound() => MatchingRound(
      targetWordKey: UtteranceKey.wordHundur,
      targetWordSlug: 'hundur',
      correctLetter: kIcelandicAlphabet.firstWhere((l) => l.glyph == 'h'),
      options: <dynamic>[
        kIcelandicAlphabet.firstWhere((l) => l.glyph == 'h'),
        kIcelandicAlphabet.firstWhere((l) => l.glyph == 'b'),
        kIcelandicAlphabet.firstWhere((l) => l.glyph == 'k'),
        kIcelandicAlphabet.firstWhere((l) => l.glyph == 's'),
      ].cast(),
      imageSource: const ImageSource.stockPlaceholder(wordSlug: 'hundur'),
    );

MatchingRound _photoRound(String photoId) => MatchingRound(
      targetWordKey: UtteranceKey.wordHundur,
      targetWordSlug: 'hundur',
      correctLetter: kIcelandicAlphabet.firstWhere((l) => l.glyph == 'h'),
      options: <dynamic>[
        kIcelandicAlphabet.firstWhere((l) => l.glyph == 'h'),
        kIcelandicAlphabet.firstWhere((l) => l.glyph == 'b'),
        kIcelandicAlphabet.firstWhere((l) => l.glyph == 'k'),
        kIcelandicAlphabet.firstWhere((l) => l.glyph == 's'),
      ].cast(),
      imageSource: ImageSource.photoOverride(photoId: photoId),
    );

void main() {
  group('providers', () {
    test('P1: photoOverrideSourceProvider returns EmptyPhotoOverrideSource', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final src = container.read(photoOverrideSourceProvider);
      expect(src, isA<EmptyPhotoOverrideSource>());
    });

    test('P2: roundGeneratorProvider returns a working RoundGenerator', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final gen = container.read(roundGeneratorProvider);
      expect(gen, isA<RoundGenerator>());
      // Defensive: production manifest has wordHundur (Phase 2 stub) so
      // generate() should not throw.
      final round = gen.generate();
      expect(round, isA<MatchingRound>());
    });
  });

  group('MatchingRoundImage', () {
    Widget _wrap(MatchingRound round) => ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 600,
                height: 400,
                child: MatchingRoundImage(round: round),
              ),
            ),
          ),
        );

    testWidgets('I1: StockPlaceholder renders Container with slug Text',
        (tester) async {
      await tester.pumpWidget(_wrap(_stockRound()));
      await tester.pump();
      expect(find.text('hundur'), findsOneWidget);
      expect(
        find.byKey(const Key('matching-stock-placeholder-hundur')),
        findsOneWidget,
      );
    });

    testWidgets('I2: PhotoOverride renders with photoId-keyed placeholder',
        (tester) async {
      await tester.pumpWidget(_wrap(_photoRound('photo-uuid-7')));
      await tester.pump();
      expect(
        find.byKey(const Key('matching-photo-override-photo-uuid-7')),
        findsOneWidget,
      );
      expect(find.text('photo-uuid-7'), findsOneWidget);
    });

    testWidgets('I3: widget centers content and expands to parent width',
        (tester) async {
      await tester.pumpWidget(_wrap(_stockRound()));
      await tester.pump();
      // The placeholder Container should occupy 80% of parent width = 480.
      final containerFinder = find.byKey(
        const Key('matching-stock-placeholder-hundur'),
      );
      final size = tester.getSize(containerFinder);
      expect(size.width, closeTo(600 * 0.8, 1.0));
    });

    testWidgets('I4: no instructional / score / timer text', (tester) async {
      await tester.pumpWidget(_wrap(_stockRound()));
      await tester.pump();
      // Exactly one Text widget (the placeholder/photoId label).
      expect(find.byType(Text), findsOneWidget);
      // No digits anywhere — no scores or counters.
      expect(find.byWidgetPredicate(
        (w) => w is Text && (w.data ?? '').contains(RegExp(r'\d')),
      ), findsNothing);
    });
  });
}
