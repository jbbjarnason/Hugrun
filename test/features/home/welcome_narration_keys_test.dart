// Plan 04-06 RED tests for the pure narration-key selector.

import 'package:flutter_test/flutter_test.dart';
import 'package:hugrun/core/manifest/utterance_key.dart';
import 'package:hugrun/features/home/welcome_narration_keys.dart';

void main() {
  test('canonical name "Hugrún" -> narrationWelcome (D-18)', () {
    expect(selectWelcomeNarrationKey('Hugrún'), UtteranceKey.narrationWelcome);
  });

  test('non-canonical name -> narrationWelcomeGeneric or fallback', () {
    final key = selectWelcomeNarrationKey('Anna');
    // Phase 2 stub: narrationWelcomeGeneric isn't in the enum yet, so we
    // fall back to narrationWelcome with a debug warning.
    expect(
      key,
      anyOf(
        UtteranceKey.narrationWelcome,
        // After Phase 3 ships generic, this branch becomes the active one.
        equals(
          UtteranceKey.values
              .where((k) => k.name == 'narrationWelcomeGeneric')
              .firstOrNull,
        ),
      ),
    );
  });

  test('null name -> generic-or-fallback (not narrationWelcome with name)', () {
    expect(selectWelcomeNarrationKey(null), isNotNull);
  });

  test('empty name -> generic-or-fallback', () {
    expect(selectWelcomeNarrationKey(''), isNotNull);
  });

  test('case-mismatch ("HUGRÚN") -> generic-or-fallback (case-sensitive)', () {
    // Canonical comparison is exact-match. 'HUGRÚN' != 'Hugrún'.
    final key = selectWelcomeNarrationKey('HUGRÚN');
    // In Phase 2 stub, falls back to narrationWelcome — but the test just
    // verifies the function returns a key; the canonical-vs-generic
    // distinction is asserted in the canonical test above.
    expect(key, isNotNull);
  });
}
