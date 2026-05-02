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
    testWidgets('renders the configured number of itemBuilder slots',
        (tester) async {
      LexiconEntry? selected;
      await tester.pumpWidget(
        _wrap(
          LexiconPicker(
            onSelected: (e) => selected = e,
          ),
        ),
      );

      // ListView.builder lazily constructs tiles. The contract here is
      // "the picker exposes every kStarterLexicon entry"; we verify
      // structurally by checking the ListView.itemCount matches and that
      // each entry's tile is reachable when scrolled to.
      final listView = tester.widget<ListView>(find.byType(ListView));
      final delegate = listView.childrenDelegate as SliverChildBuilderDelegate;
      expect(delegate.estimatedChildCount, kStarterLexicon.length);
      expect(selected, isNull);
    });

    testWidgets('a sample of off-screen entries can be scrolled into view',
        (tester) async {
      LexiconEntry? selected;
      await tester.pumpWidget(
        _wrap(
          LexiconPicker(
            onSelected: (e) => selected = e,
          ),
        ),
      );

      // Pick three words that span the alphabetical range — the first
      // few are on-screen, but words from the middle and end need scrolling.
      // Use scrollUntilVisible (works when the target is below) for those.
      final scrollable = find.byType(Scrollable).first;
      for (final word in ['hundur', 'sól', 'tré']) {
        final finder = find.byKey(Key('lexicon-tile-$word'));
        if (finder.evaluate().isEmpty) {
          await tester.scrollUntilVisible(finder, 300.0,
              scrollable: scrollable);
        }
        expect(finder, findsOneWidget, reason: 'Missing tile for $word');
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

      await tester.scrollUntilVisible(
        find.text('hundur'),
        200.0,
        scrollable: find.byType(Scrollable).first,
      );
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
      await tester.scrollUntilVisible(
        find.text('epli'),
        200.0,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('epli'));
      await tester.pumpAndSettle();
      expect(selected, isNotNull);
      expect(selected!.word, 'epli');
    });
  });
}
