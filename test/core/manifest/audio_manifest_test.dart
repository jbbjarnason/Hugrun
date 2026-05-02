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

/// Authoritative D-08 path map (the spot-check fixture).
const Map<UtteranceKey, String> kExpectedPaths = <UtteranceKey, String>{
  UtteranceKey.letterA: 'assets/audio/letters/names/a.aac',
  UtteranceKey.letterEth: 'assets/audio/letters/names/eth.aac',
  UtteranceKey.letterThorn: 'assets/audio/letters/names/thorn.aac',
  UtteranceKey.wordHundur: 'assets/audio/letters/words/hundur.aac',
  UtteranceKey.narrationWelcome: 'assets/audio/narration/welcome_hugrun.aac',
};

/// D-06 path-convention regex (lowercase ASCII alphanumerics + `_`/`-`/`/`/`.`,
/// must end in `.aac`).
final RegExp _pathConventionRegex = RegExp(r'^[a-z0-9_./-]+\.aac$');

void main() {
  group('UtteranceKey', () {
    test('has exactly 5 entries (D-08)', () {
      expect(UtteranceKey.values.length, 5);
    });

    test('contains exactly the 5 D-08 entries', () {
      expect(UtteranceKey.values.toSet(), {
        UtteranceKey.letterA,
        UtteranceKey.letterEth,
        UtteranceKey.letterThorn,
        UtteranceKey.wordHundur,
        UtteranceKey.narrationWelcome,
      });
    });
  });

  group('kAudioManifest', () {
    test('every UtteranceKey maps to a non-null AudioAsset (D-11)', () {
      for (final key in UtteranceKey.values) {
        final asset = kAudioManifest[key];
        expect(asset, isNotNull, reason: 'Missing manifest entry for $key');
        expect(asset!.path, isNotEmpty, reason: 'Empty path for $key');
      }
    });

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
    test('returns the same asset as kAudioManifest[key] for every key', () {
      for (final key in UtteranceKey.values) {
        final viaHelper = getAudioAsset(key);
        final viaMap = kAudioManifest[key]!;
        expect(viaHelper.path, viaMap.path);
        expect(viaHelper, viaMap);
      }
    });

    test('exhaustive switch over UtteranceKey returns a non-empty path', () {
      // This is the contract Phase 3 needs: adding a new enum value without
      // a manifest entry surfaces fast. The exhaustive switch catches at
      // compile time; the assertion catches at test time if a future hand
      // edit somehow lets an empty path through.
      for (final key in UtteranceKey.values) {
        final path = switch (key) {
          UtteranceKey.letterA => kAudioManifest[UtteranceKey.letterA]!.path,
          UtteranceKey.letterEth =>
            kAudioManifest[UtteranceKey.letterEth]!.path,
          UtteranceKey.letterThorn =>
            kAudioManifest[UtteranceKey.letterThorn]!.path,
          UtteranceKey.wordHundur =>
            kAudioManifest[UtteranceKey.wordHundur]!.path,
          UtteranceKey.narrationWelcome =>
            kAudioManifest[UtteranceKey.narrationWelcome]!.path,
        };
        expect(path, isNotEmpty);
      }
    });
  });
}
