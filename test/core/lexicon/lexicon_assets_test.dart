// Phase 11 — Asset existence test for the lexicon image library.
//
// Verifies that every entry in [kStarterLexicon] has a corresponding image
// file on disk at its [LexiconEntry.defaultImagePath]. Phase 4's
// `ExampleWordOverlay` and Phase 5/9 activities silently fall back to
// text-on-color placeholders when an image is missing — that fallback was
// the actual UX bug Phase 11 fixes. This test guards against regression.
//
// Also covers the auxiliary slugs referenced by lib/core/numbers/
// correspondence_round.dart (`lampi`, `ros`) which sit outside the
// lexicon proper but are still required by Phase 9's correspondence /
// addition rounds. If a future plan adds new slugs to either set, add
// them to [_kRequiredAuxSlugs] below.
//
// Failure mode: rather than crashing on the first missing file, this
// collects ALL missing entries and reports them in one assertion so a
// developer running the test on a fresh checkout sees the full picture.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hugrun/core/lexicon/lexicon.dart';

/// Auxiliary slugs referenced outside [kStarterLexicon] but still bundled
/// in the asset library. Mirrors lib/core/numbers/correspondence_round.dart.
const Set<String> _kRequiredAuxSlugs = <String>{'lampi', 'ros'};

const String _kImageDir = 'assets/images/letters/words';

void main() {
  group('Phase 11 — lexicon image asset library', () {
    test('every kStarterLexicon entry has a real .webp file on disk', () {
      final missing = <String>[];

      for (final entry in kStarterLexicon) {
        final path = entry.defaultImagePath;
        // All canonical paths should end in .webp per Phase 11 D-06.
        expect(
          path,
          endsWith('.webp'),
          reason: 'kStarterLexicon[${entry.word}] should reference a .webp '
              'asset, got: $path',
        );
        if (!File(path).existsSync()) {
          missing.add('${entry.word} -> $path');
        }
      }

      expect(
        missing,
        isEmpty,
        reason: 'Lexicon image files missing — ExampleWordOverlay will fall '
            'back to text-on-color placeholders for these entries:\n'
            '  ${missing.join('\n  ')}\n'
            'Run: python3 tools/images/generate_lexicon_images.py',
      );
    });

    test('every required auxiliary slug has a real .webp file on disk', () {
      final missing = <String>[];
      for (final slug in _kRequiredAuxSlugs) {
        final path = '$_kImageDir/$slug.webp';
        if (!File(path).existsSync()) {
          missing.add('$slug -> $path');
        }
      }
      expect(
        missing,
        isEmpty,
        reason: 'Auxiliary slug image files missing (used by '
            'lib/core/numbers/correspondence_round.dart):\n'
            '  ${missing.join('\n  ')}',
      );
    });

    test('every image file is ≤200KB (Phase 11 size budget)', () {
      const sizeBudgetBytes = 200 * 1024;
      final oversized = <String>[];

      final dir = Directory(_kImageDir);
      if (!dir.existsSync()) {
        fail('Image directory does not exist: $_kImageDir');
      }
      for (final f in dir.listSync()) {
        if (f is! File) continue;
        if (!f.path.endsWith('.webp')) continue;
        final bytes = f.lengthSync();
        if (bytes > sizeBudgetBytes) {
          oversized.add('${f.path} = ${(bytes / 1024).toStringAsFixed(1)}KB');
        }
      }
      expect(
        oversized,
        isEmpty,
        reason: 'Some lexicon images exceed the 200KB-per-image budget:\n'
            '  ${oversized.join('\n  ')}',
      );
    });

    test('every image filename uses lowercase ASCII (matches D-06 / slug rules)',
        () {
      final dir = Directory(_kImageDir);
      if (!dir.existsSync()) {
        fail('Image directory does not exist: $_kImageDir');
      }
      final pattern = RegExp(r'^[a-z0-9._-]+$');
      final bad = <String>[];
      for (final f in dir.listSync()) {
        if (f is! File) continue;
        final name = f.uri.pathSegments.last;
        if (name == '.gitkeep') continue;
        if (!pattern.hasMatch(name)) {
          bad.add(name);
        }
      }
      expect(
        bad,
        isEmpty,
        reason: 'Lexicon image filenames violate D-06 (lowercase ASCII '
            '[a-z0-9._-] only):\n  ${bad.join('\n  ')}',
      );
    });
  });
}
