// Phase 2 Plan 01: smoke tests for the freezed IcelandicLetter model.
// Confirms @freezed generated == / hashCode / copyWith.
import 'package:flutter_test/flutter_test.dart';
import 'package:hugrun/core/alphabet/icelandic_letter.dart';

void main() {
  group('IcelandicLetter (@freezed)', () {
    test('two instances with the same fields are equal', () {
      const a = IcelandicLetter(glyph: 'a', name: 'a', assetSlug: 'a');
      const b = IcelandicLetter(glyph: 'a', name: 'a', assetSlug: 'a');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('instances with different fields are not equal', () {
      const a = IcelandicLetter(glyph: 'a', name: 'a', assetSlug: 'a');
      const b = IcelandicLetter(glyph: 'á', name: 'á', assetSlug: 'a_acute');
      expect(a, isNot(equals(b)));
    });

    test('copyWith returns a new instance with the new field, others unchanged',
        () {
      const original = IcelandicLetter(
        glyph: 'a',
        name: 'a',
        assetSlug: 'a',
      );
      final copy = original.copyWith(assetSlug: 'x_test');
      expect(copy.assetSlug, 'x_test');
      expect(copy.glyph, original.glyph);
      expect(copy.name, original.name);
      expect(copy, isNot(equals(original)));
    });
  });
}
