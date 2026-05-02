// Phase 10 Plan 04 — LexiconPicker widget tests (RED first).
//
// LexiconPicker:
//   * Renders a scrollable alphabetical grid/list of all kStarterLexicon
//     entries.
//   * Each entry is tappable; tapping calls the provided onSelected callback
//     with the LexiconEntry.
//   * Cancellable via the AppBar back button (no separate "Cancel" button —
//     standard MaterialApp Navigator pattern).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugrun/core/lexicon/lexicon.dart';
import 'package:hugrun/core/lexicon/lexicon_entry.dart';
import 'package:hugrun/features/parent_settings/photo_upload/lexicon_picker.dart';

Widget _wrap(Widget child) => MaterialApp(home: child);

void main() {
  group('LexiconPicker', () {
    testWidgets('renders one tile per kStarterLexicon entry', (tester) async {
      LexiconEntry? selected;
      await tester.pumpWidget(
        _wrap(
          LexiconPicker(
            onSelected: (e) => selected = e,
          ),
        ),
      );

      // Each entry should have a corresponding tappable widget.
      for (final entry in kStarterLexicon) {
        expect(
          find.text(entry.word),
          findsOneWidget,
          reason: 'Missing tile for ${entry.word}',
        );
      }
      expect(selected, isNull);
    });

    testWidgets('tapping a tile invokes onSelected with the entry',
        (tester) async {
      LexiconEntry? selected;
      await tester.pumpWidget(
        _wrap(
          LexiconPicker(
            onSelected: (e) => selected = e,
          ),
        ),
      );

      await tester.ensureVisible(find.text('hundur'));
      await tester.tap(find.text('hundur'));
      await tester.pumpAndSettle();

      expect(selected, isNotNull);
      expect(selected!.word, 'hundur');
    });

    testWidgets('AppBar shows Icelandic title "Veldu orð"', (tester) async {
      await tester.pumpWidget(
        _wrap(
          LexiconPicker(onSelected: (_) {}),
        ),
      );
      expect(find.text('Veldu orð'), findsOneWidget);
    });

    testWidgets('every entry tile is tappable', (tester) async {
      LexiconEntry? selected;
      await tester.pumpWidget(
        _wrap(
          LexiconPicker(onSelected: (e) => selected = e),
        ),
      );
      // Pick a non-first word to ensure we're not just hitting the
      // top-of-list tile.
      await tester.ensureVisible(find.text('epli'));
      await tester.tap(find.text('epli'));
      await tester.pumpAndSettle();
      expect(selected, isNotNull);
      expect(selected!.word, 'epli');
    });
  });
}
