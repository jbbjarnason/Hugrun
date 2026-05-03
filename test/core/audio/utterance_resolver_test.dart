// Plan 04-02 RED tests for the letter -> (name, optional word) resolver.
// Tests use override parameters so they're independent of Phase 2 stub vs
// Phase 3 generated manifest state.

import 'package:flutter_test/flutter_test.dart';
import 'package:hugrun/core/audio/utterance_resolver.dart';
import 'package:hugrun/core/manifest/audio_asset.dart';
import 'package:hugrun/core/manifest/utterance_key.dart';

void main() {
  // A constant-known stub manifest used to exercise the resolver behavior
  // without depending on the live kAudioManifest contents.
  const stubManifest = <UtteranceKey, AudioAsset>{
    UtteranceKey.letterA: AudioAsset(
      path: 'assets/audio/letters/names/a.aac',
      approximateDuration: Duration(milliseconds: 100),
    ),
    UtteranceKey.letterEth: AudioAsset(
      path: 'assets/audio/letters/names/eth.aac',
      approximateDuration: Duration(milliseconds: 100),
    ),
    UtteranceKey.letterThorn: AudioAsset(
      path: 'assets/audio/letters/names/thorn.aac',
      approximateDuration: Duration(milliseconds: 100),
    ),
    UtteranceKey.wordHundur: AudioAsset(
      path: 'assets/audio/letters/words/hundur.aac',
      approximateDuration: Duration(milliseconds: 100),
    ),
    UtteranceKey.narrationWelcome: AudioAsset(
      path: 'assets/audio/narration/welcome_hugrun.aac',
      approximateDuration: Duration(milliseconds: 100),
    ),
  };

  group('resolveLetterToClips', () {
    test(
      'letterA returns ResolvedUtterance(nameKey=letterA, wordKey=null) under empty pairing table',
      () {
        final r = resolveLetterToClips(
          UtteranceKey.letterA,
          manifestOverride: stubManifest,
          pairingOverride: const <UtteranceKey, UtteranceKey>{},
        );
        expect(r.nameKey, UtteranceKey.letterA);
        expect(r.wordKey, isNull);
      },
    );

    test('narrationWelcome is atomic (no example word)', () {
      final r = resolveLetterToClips(
        UtteranceKey.narrationWelcome,
        manifestOverride: stubManifest,
      );
      expect(r.nameKey, UtteranceKey.narrationWelcome);
      expect(r.wordKey, isNull);
    });

    test('wordHundur played alone is atomic (no follow-up)', () {
      final r = resolveLetterToClips(
        UtteranceKey.wordHundur,
        manifestOverride: stubManifest,
      );
      expect(r.nameKey, UtteranceKey.wordHundur);
      expect(r.wordKey, isNull);
    });

    test(
      'returns wordKey when pairing table has entry AND target exists in manifest',
      () {
        final r = resolveLetterToClips(
          UtteranceKey.letterA,
          manifestOverride: stubManifest,
          pairingOverride: const <UtteranceKey, UtteranceKey>{
            UtteranceKey.letterA: UtteranceKey.wordHundur,
          },
        );
        expect(r.nameKey, UtteranceKey.letterA);
        expect(r.wordKey, UtteranceKey.wordHundur);
      },
    );

    test('returns null wordKey when pairing target is missing from manifest', () {
      // Pairing says letterA -> wordHundur, but manifest doesn't have wordHundur.
      const manifestWithoutHundur = <UtteranceKey, AudioAsset>{
        UtteranceKey.letterA: AudioAsset(
          path: 'assets/audio/letters/names/a.aac',
          approximateDuration: Duration(milliseconds: 100),
        ),
      };
      final r = resolveLetterToClips(
        UtteranceKey.letterA,
        manifestOverride: manifestWithoutHundur,
        pairingOverride: const <UtteranceKey, UtteranceKey>{
          UtteranceKey.letterA: UtteranceKey.wordHundur,
        },
      );
      expect(r.nameKey, UtteranceKey.letterA);
      expect(
        r.wordKey,
        isNull,
        reason: 'Phase 2 stub fallback: pairing target absent → no word',
      );
    });
  });
}
