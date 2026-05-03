// Phase 2 Plan 02 D-11 unit tests for the audio manifest stub.
//
// Source of truth: 02-CONTEXT.md D-08 (UtteranceKey + AudioAsset shape),
// D-09 (placeholder AAC files), D-11 (assertions).
//
// PITFALL #20: manifest paths must be lowercase ASCII so iOS Simulator
// (case-insensitive APFS) and Linux CI / Android (case-sensitive) agree on
// every path. This test file is the safety net before plan 02-03's CI guard
// catches the same issue at the build-tree level.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hugrun/core/manifest/utterance_key.dart';
import 'package:hugrun/gen/audio_manifest.g.dart';

/// Authoritative D-08 path map for the Phase 2 stub keys (the spot-check
/// fixture). Phase 6 D-21 adds 40 more enum values that are intentionally
/// absent from `kAudioManifest` until the audio review pass repopulates
/// `lib/gen/audio_manifest.g.dart`.
const Map<UtteranceKey, String> kExpectedPaths = <UtteranceKey, String>{
  UtteranceKey.letterA: 'assets/audio/letters/names/a.aac',
  UtteranceKey.letterEth: 'assets/audio/letters/names/eth.aac',
  UtteranceKey.letterThorn: 'assets/audio/letters/names/thorn.aac',
  UtteranceKey.wordHundur: 'assets/audio/letters/words/hundur.aac',
  UtteranceKey.narrationWelcome: 'assets/audio/narration/welcome_hugrun.aac',
};

/// Phase 2 stub keys: present in `kAudioManifest`. Asserts in this group
/// only iterate over these.
const Set<UtteranceKey> kPhase2StubKeys = <UtteranceKey>{
  UtteranceKey.letterA,
  UtteranceKey.letterEth,
  UtteranceKey.letterThorn,
  UtteranceKey.wordHundur,
  UtteranceKey.narrationWelcome,
};

/// D-06 path-convention regex (lowercase ASCII alphanumerics + `_`/`-`/`/`/`.`,
/// must end in `.aac`).
final RegExp _pathConventionRegex = RegExp(r'^[a-z0-9_./-]+\.aac$');

void main() {
  group('UtteranceKey', () {
    test('Phase 2 stub keys are all present (D-22 backward compat)', () {
      // Phase 6 extends the enum (D-01..D-07) but the 5 Phase 2 stub keys
      // must remain — Phase 4 + 5 still depend on them.
      expect(UtteranceKey.values.toSet(), containsAll(kPhase2StubKeys));
    });

    test('Phase 6 phoneme keys are all present (D-01; CVC-02)', () {
      // 32 phoneme<X> entries must exist for the 32-letter alphabet.
      final phonemeKeys = UtteranceKey.values
          .where((k) => k.name.startsWith('phoneme'))
          .toSet();
      expect(
        phonemeKeys.length,
        32,
        reason:
            'Expected 32 phoneme<X> enum entries, got '
            '${phonemeKeys.length}: ${phonemeKeys.map((k) => k.name).toList()}',
      );
    });

    test('Phase 6 new CVC word keys are present (D-04)', () {
      // hús, hár, gás are NEW in Phase 6 (not part of the 32 letter
      // example-word set in Phase 3).
      expect(UtteranceKey.values, contains(UtteranceKey.wordHus));
      expect(UtteranceKey.values, contains(UtteranceKey.wordHar));
      expect(UtteranceKey.values, contains(UtteranceKey.wordGas));
    });

    test('Phase 6 reused CVC word keys are present (D-04)', () {
      // kýr/sól/mús/rós/bók re-use the Phase-3 example_word slots.
      expect(UtteranceKey.values, contains(UtteranceKey.wordK));
      expect(UtteranceKey.values, contains(UtteranceKey.wordS));
      expect(UtteranceKey.values, contains(UtteranceKey.wordM));
      expect(UtteranceKey.values, contains(UtteranceKey.wordR));
      expect(UtteranceKey.values, contains(UtteranceKey.wordB));
    });
  });

  group('kAudioManifest', () {
    test('every Phase 2 stub key maps to a non-null AudioAsset (D-11)', () {
      for (final key in kPhase2StubKeys) {
        final asset = kAudioManifest[key];
        expect(asset, isNotNull, reason: 'Missing manifest entry for $key');
        expect(asset!.path, isNotEmpty, reason: 'Empty path for $key');
      }
    });

    test(
      'Phase 6 phoneme + new word keys are present in the manifest (Phase 13)',
      () {
        // Pre-Phase-13: D-21 silent-fallback meant these keys were absent
        // until the native-speaker review pass landed.
        // Phase 13: technical-review pass regenerates the manifest with
        // every entry present, gated by `technically_reviewed: true`.
        // Pronunciation is still pending — the file carries
        // `// PRONUNCIATION REVIEW PENDING` markers. The kid hears audio,
        // but a native-speaker pass should run before shipping.
        final phase6Keys = UtteranceKey.values
            .where(
              (k) =>
                  k.name.startsWith('phoneme') ||
                  k == UtteranceKey.wordHus ||
                  k == UtteranceKey.wordHar ||
                  k == UtteranceKey.wordGas ||
                  k == UtteranceKey.wordK ||
                  k == UtteranceKey.wordS ||
                  k == UtteranceKey.wordM ||
                  k == UtteranceKey.wordR ||
                  k == UtteranceKey.wordB,
            )
            .toList();
        for (final k in phase6Keys) {
          expect(
            kAudioManifest[k],
            isNotNull,
            reason: 'Phase 13 expected $k to be present in kAudioManifest',
          );
        }
      },
    );

    test('every manifest path resolves to a real file on disk (D-11)', () {
      for (final entry in kAudioManifest.entries) {
        final path = entry.value.path;
        expect(
          File(path).existsSync(),
          isTrue,
          reason:
              'Manifest entry ${entry.key} points to nonexistent file "$path"',
        );
      }
    });

    test('every manifest path conforms to D-06 conventions', () {
      for (final entry in kAudioManifest.entries) {
        final path = entry.value.path;
        expect(
          _pathConventionRegex.hasMatch(path),
          isTrue,
          reason:
              'Path "$path" for ${entry.key} does not match ^[a-z0-9_./-]+\\.aac\$',
        );
        expect(path.contains('..'), isFalse, reason: '$path contains ".."');
        expect(path.contains('//'), isFalse, reason: '$path contains "//"');
        expect(
          path.startsWith('/'),
          isFalse,
          reason: '$path is absolute, expected project-relative',
        );
      }
    });

    test('exact paths match the D-08 spot-check map', () {
      for (final entry in kExpectedPaths.entries) {
        final asset = kAudioManifest[entry.key];
        expect(asset, isNotNull, reason: 'Missing entry for ${entry.key}');
        expect(
          asset!.path,
          entry.value,
          reason: 'Path mismatch for ${entry.key}',
        );
      }
    });
  });

  group('getAudioAsset', () {
    test(
      'returns the same asset as kAudioManifest[key] for every Phase 2 stub key',
      () {
        for (final key in kPhase2StubKeys) {
          final viaHelper = getAudioAsset(key);
          final viaMap = kAudioManifest[key]!;
          expect(viaHelper.path, viaMap.path);
          expect(viaHelper, viaMap);
        }
      },
    );
  });
}
