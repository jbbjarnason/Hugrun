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
    test(
      'P1: photoOverrideSourceProvider returns EmptyPhotoOverrideSource',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final src = container.read(photoOverrideSourceProvider);
        expect(src, isA<EmptyPhotoOverrideSource>());
      },
    );

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

  /// A round whose slug intentionally has no shipped lexicon image, so the
  /// errorBuilder fallback path renders the slug as text. Mirrors the
  /// `zz_no_asset` pattern used in example_word_overlay_test.dart.
  MatchingRound missingAssetRound() => MatchingRound(
    targetWordKey: UtteranceKey.wordHundur,
    targetWordSlug: 'zz_no_asset',
    correctLetter: kIcelandicAlphabet.firstWhere((l) => l.glyph == 'h'),
    options: <dynamic>[
      kIcelandicAlphabet.firstWhere((l) => l.glyph == 'h'),
      kIcelandicAlphabet.firstWhere((l) => l.glyph == 'b'),
      kIcelandicAlphabet.firstWhere((l) => l.glyph == 'k'),
      kIcelandicAlphabet.firstWhere((l) => l.glyph == 's'),
    ].cast(),
    imageSource: const ImageSource.stockPlaceholder(wordSlug: 'zz_no_asset'),
  );

  group('MatchingRoundImage', () {
    Widget wrap(MatchingRound round) => ProviderScope(
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

    testWidgets(
      'I1: StockPlaceholder with shipped lexicon image renders Image.asset',
      (tester) async {
        // Phase 11 baked `assets/images/letters/words/hundur.webp` so the
        // matching round's StockPlaceholder now resolves to that asset
        // instead of the text-on-color placeholder.
        await tester.pumpWidget(wrap(_stockRound()));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('matching-stock-placeholder-hundur')),
          findsOneWidget,
        );
        // Image renders; no text fallback is mounted when the asset succeeds.
        expect(find.byType(Image), findsOneWidget);
        expect(find.text('hundur'), findsNothing);
      },
    );

    testWidgets(
      'I1b: StockPlaceholder with missing asset falls back to slug text',
      (tester) async {
        await tester.pumpWidget(wrap(missingAssetRound()));
        // Pump multiple frames so Image.asset's errorBuilder fires for the
        // missing asset path.
        await tester.pumpAndSettle();
        expect(find.text('zz_no_asset'), findsOneWidget);
        expect(
          find.byKey(const Key('matching-stock-placeholder-zz_no_asset')),
          findsOneWidget,
        );
      },
    );

    testWidgets('I2: PhotoOverride renders with photoId-keyed placeholder', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(_photoRound('photo-uuid-7')));
      await tester.pump();
      expect(
        find.byKey(const Key('matching-photo-override-photo-uuid-7')),
        findsOneWidget,
      );
      // PhotoOverride keeps the labeled-text placeholder until Phase 10
      // ships real photo loading.
      expect(find.text('photo-uuid-7'), findsOneWidget);
    });

    testWidgets('I3: widget centers content and expands to parent width', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(_stockRound()));
      await tester.pumpAndSettle();
      // The placeholder Container should occupy 80% of parent width = 480.
      final containerFinder = find.byKey(
        const Key('matching-stock-placeholder-hundur'),
      );
      final size = tester.getSize(containerFinder);
      expect(size.width, closeTo(600 * 0.8, 1.0));
    });

    testWidgets('I4: no instructional / score / timer text', (tester) async {
      // With the shipped lexicon image, no Text widget is rendered at all
      // (the errorBuilder doesn't fire). With the missing-asset round we
      // see the slug label only. Either way: no digits, no instruction
      // text — same invariant.
      await tester.pumpWidget(wrap(missingAssetRound()));
      await tester.pumpAndSettle();
      // Exactly one Text — the slug label rendered by the errorBuilder.
      expect(find.byType(Text), findsOneWidget);
      // No digits anywhere — no scores or counters.
      expect(
        find.byWidgetPredicate(
          (w) => w is Text && (w.data ?? '').contains(RegExp(r'\d')),
        ),
        findsNothing,
      );
    });
  });
}
