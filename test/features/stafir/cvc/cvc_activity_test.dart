// Phase 6 Plan 06-02 Task B.2 RED — widget tests for CvcActivity.
//
// CvcActivity is the heart of the CVC blending experience (CVC-01..03).
// One round shows the word's image + 3 LetterTiles (c1, v, c2). The child
// taps each letter, hears its phoneme, and after all 3 are tapped the
// narrator plays the full word blend.
//
// Critical invariants:
//   - C1: layout — 1 image area + 3 LetterTiles (NOT 4 like matching).
//   - C3: tapping a tile fires AudioEngine.play(phonemeKey) for that letter.
//   - C5: tap-order tolerance — child can tap c2 first, c1 next, v last.
//   - C6: blend plays after ALL 3 are tapped (regardless of order).
//   - C7: re-tapping an already-tapped letter replays its phoneme (D-14).
//   - C8: untapped letter taps don't fire the blend.

// ignore_for_file: scoped_providers_should_specify_dependencies

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugrun/core/audio/audio_engine_provider.dart';
import 'package:hugrun/core/cvc/cvc_word.dart';
import 'package:hugrun/core/cvc/cvc_words.dart';
import 'package:hugrun/core/manifest/utterance_key.dart';
import 'package:hugrun/features/stafir/cvc/cvc_activity.dart';
import 'package:hugrun/features/stafir/cvc/cvc_providers.dart';
import 'package:hugrun/features/stafir/widgets/letter_tile.dart';

import '../../../../integration_test/test_helpers/fake_audio_engine.dart';

CvcWord _husWord() => kCvcWords.firstWhere((w) => w.word == 'hús');
CvcWord _kyrWord() => kCvcWords.firstWhere((w) => w.word == 'kýr');
// `hár` has no `har.webp` shipped in Phase 11's lexicon — used to verify
// the errorBuilder fallback path renders the word string as text.
CvcWord _harWord() => kCvcWords.firstWhere((w) => w.word == 'hár');

ProviderScope _wrap({required FakeAudioEngine engine, required CvcWord word}) {
  return ProviderScope(
    overrides: [
      audioEngineProvider.overrideWith((ref) => engine),
      // Force a deterministic round by overriding the round provider.
      cvcCurrentWordProvider.overrideWith((ref) => word),
    ],
    child: const MaterialApp(home: Scaffold(body: CvcActivity())),
  );
}

void main() {
  testWidgets('C1: layout — image area + 3 LetterTiles (NOT 4)', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final engine = FakeAudioEngine();
    await tester.pumpWidget(_wrap(engine: engine, word: _husWord()));
    await tester.pump();
    await tester.pump();

    expect(find.byType(LetterTile), findsNWidgets(3));
  });

  testWidgets('C2: tiles render in display order [c1, v, c2]', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final engine = FakeAudioEngine();
    final word = _husWord(); // h-ú-s
    await tester.pumpWidget(_wrap(engine: engine, word: word));
    await tester.pump();
    await tester.pump();

    final tiles = tester
        .widgetList<LetterTile>(find.byType(LetterTile))
        .map((t) => t.letter.glyph)
        .toList();
    expect(tiles, <String>['h', 'ú', 's']);
  });

  testWidgets('C3: tapping c1 plays the c1 phoneme key', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final engine = FakeAudioEngine();
    await tester.pumpWidget(_wrap(engine: engine, word: _husWord()));
    await tester.pump();
    await tester.pump();

    // Tap the 'h' tile — first one (c1).
    await tester.tap(find.byKey(const Key('cvc-tile-0-h')));
    await tester.pump();
    expect(engine.playCalls.last, UtteranceKey.phonemeH);
  });

  testWidgets('C4: tapping v plays the vowel phoneme', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final engine = FakeAudioEngine();
    await tester.pumpWidget(_wrap(engine: engine, word: _husWord()));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byKey(const Key('cvc-tile-1-u_acute')));
    await tester.pump();
    expect(engine.playCalls.last, UtteranceKey.phonemeUAcute);
  });

  testWidgets('C5: tap-order tolerance — c2 first is accepted', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final engine = FakeAudioEngine();
    await tester.pumpWidget(_wrap(engine: engine, word: _husWord()));
    await tester.pump();
    await tester.pump();

    // Tap c2 ('s') first — must NOT throw, must play phonemeS.
    await tester.tap(find.byKey(const Key('cvc-tile-2-s')));
    await tester.pump();
    expect(engine.playCalls, contains(UtteranceKey.phonemeS));
    // Blend not fired yet — only 1/3 tapped.
    expect(engine.playCalls.contains(UtteranceKey.wordHus), isFalse);
  });

  testWidgets(
    'C6: blend plays after all 3 letters tapped, regardless of order',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final engine = FakeAudioEngine();
      await tester.pumpWidget(_wrap(engine: engine, word: _husWord()));
      await tester.pump();
      await tester.pump();

      // Tap in REVERSE order: c2, v, c1.
      await tester.tap(find.byKey(const Key('cvc-tile-2-s')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('cvc-tile-1-u_acute')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('cvc-tile-0-h')));
      await tester.pump(const Duration(milliseconds: 100));

      // After third tap, the blend (wordHus) should have been played.
      expect(engine.playCalls, contains(UtteranceKey.wordHus));
      // And blend is the LAST entry — fires after the third phoneme.
      expect(engine.playCalls.last, UtteranceKey.wordHus);
    },
  );

  testWidgets('C7: re-tapping a letter replays its phoneme (D-14)', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final engine = FakeAudioEngine();
    await tester.pumpWidget(_wrap(engine: engine, word: _husWord()));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byKey(const Key('cvc-tile-0-h')));
    await tester.pump();
    final firstCount = engine.playCalls
        .where((k) => k == UtteranceKey.phonemeH)
        .length;

    // Re-tap.
    await tester.tap(find.byKey(const Key('cvc-tile-0-h')));
    await tester.pump();
    final secondCount = engine.playCalls
        .where((k) => k == UtteranceKey.phonemeH)
        .length;
    expect(secondCount, firstCount + 1, reason: 'phoneme should replay');
  });

  testWidgets('C8: blend does NOT play with only 2 of 3 tapped', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final engine = FakeAudioEngine();
    await tester.pumpWidget(_wrap(engine: engine, word: _husWord()));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byKey(const Key('cvc-tile-0-h')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('cvc-tile-1-u_acute')));
    await tester.pump(const Duration(milliseconds: 100));

    expect(engine.playCalls.contains(UtteranceKey.wordHus), isFalse);
  });

  testWidgets('C9: re-tapping after completion does NOT replay the blend', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final engine = FakeAudioEngine();
    await tester.pumpWidget(_wrap(engine: engine, word: _husWord()));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byKey(const Key('cvc-tile-0-h')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('cvc-tile-1-u_acute')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('cvc-tile-2-s')));
    await tester.pump(const Duration(milliseconds: 100));

    // First blend played.
    final blendCount1 = engine.playCalls
        .where((k) => k == UtteranceKey.wordHus)
        .length;
    expect(blendCount1, 1);

    // Re-tap c1 — phoneme replays, but blend should NOT fire again because
    // the round is in its post-blend wait state (auto-advance handles it).
    await tester.tap(find.byKey(const Key('cvc-tile-0-h')));
    await tester.pump(const Duration(milliseconds: 100));
    final blendCount2 = engine.playCalls
        .where((k) => k == UtteranceKey.wordHus)
        .length;
    expect(blendCount2, 1, reason: 'blend should not double-fire');
  });

  testWidgets('C10: zero failure UI — no error/check/score icons', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final engine = FakeAudioEngine();
    await tester.pumpWidget(_wrap(engine: engine, word: _husWord()));
    await tester.pump();
    await tester.pump();
    expect(find.byIcon(Icons.error), findsNothing);
    expect(find.byIcon(Icons.close), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('C11: zero text instructions visible to the child', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final engine = FakeAudioEngine();
    await tester.pumpWidget(_wrap(engine: engine, word: _husWord()));
    await tester.pump();
    await tester.pump();
    // Allowed: the 3 letter glyphs + the word label on the image.
    final texts = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .whereType<String>()
        .toList();
    final asciiTextFound = texts
        .where((s) => RegExp(r'^[A-Za-z\s,.!?]+\$').hasMatch(s) && s.length > 5)
        .toList();
    expect(
      asciiTextFound,
      isEmpty,
      reason: 'No long English-style instruction text should be present',
    );
  });

  testWidgets('C12: works with kýr word too — phoneme keys resolve correctly', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final engine = FakeAudioEngine();
    await tester.pumpWidget(_wrap(engine: engine, word: _kyrWord()));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byKey(const Key('cvc-tile-0-k')));
    await tester.pump();
    expect(engine.playCalls.last, UtteranceKey.phonemeK);

    await tester.tap(find.byKey(const Key('cvc-tile-1-y_acute')));
    await tester.pump();
    expect(engine.playCalls.last, UtteranceKey.phonemeYAcute);

    await tester.tap(find.byKey(const Key('cvc-tile-2-r')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(engine.playCalls.last, UtteranceKey.wordK);
  });

  testWidgets(
    'C13 (Phase 11 fix): hús round renders Image.asset, no word-text fallback',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final engine = FakeAudioEngine();
      // hús → assets/images/letters/words/hus.webp ships in Phase 11.
      await tester.pumpWidget(_wrap(engine: engine, word: _husWord()));
      await tester.pumpAndSettle();
      // Image renders inside the round image container.
      expect(find.byType(Image), findsOneWidget);
      // The errorBuilder text 'hús' is NOT mounted while the asset succeeds.
      expect(find.text('hús'), findsNothing);
    },
  );

  testWidgets(
    'C14 (Phase 11 fix): hár round (no shipped image) falls back to text',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final engine = FakeAudioEngine();
      // hár has no `har.webp` in the Phase 11 lexicon — errorBuilder fires.
      await tester.pumpWidget(_wrap(engine: engine, word: _harWord()));
      await tester.pumpAndSettle();
      expect(find.text('hár'), findsOneWidget);
    },
  );
}
