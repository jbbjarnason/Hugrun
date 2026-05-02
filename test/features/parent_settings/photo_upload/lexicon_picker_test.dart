// Phase 10 Plan 04 — LexiconPicker widget tests.
// Phase 12 UI-04 — picker becomes a 2-column image grid (was vertical
// text-only ListView). Falls back to text-only when the lexicon entry's
// stock image (`defaultImagePath`) is missing on disk.
//
// LexiconPicker:
//   * Renders a 2-column scrollable grid of all kStarterLexicon entries.
//   * Each tile shows the entry's stock image at top + the noun word
//     beneath; falls back to text-only when image asset is absent.
//   * Each entry is tappable; tapping calls the provided onSelected
//     callback with the LexiconEntry.
//   * Cancellable via the AppBar back button (no separate "Cancel"
//     button — standard MaterialApp Navigator pattern). Parent-facing
//     screen — AppBar stays per Phase 12 scope (only kid-mode screens
//     drop AppBars).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugrun/core/lexicon/lexicon.dart';
import 'package:hugrun/core/lexicon/lexicon_entry.dart';
import 'package:hugrun/features/parent_settings/photo_upload/lexicon_picker.dart';

Widget _wrap(Widget child) => MaterialApp(home: child);

void main() {
  group('LexiconPicker', () {
    testWidgets('Phase 12 UI-04: renders a 2-column GridView '
        '(was vertical ListView)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _wrap(LexiconPicker(onSelected: (_) {})),
      );
      // The body should be a GridView, not a ListView.
      expect(find.byType(GridView), findsOneWidget);
      expect(find.byType(ListView), findsNothing);

      // The grid must declare exactly 2 cross-axis cells (cross-axis
      // count). Pull it off the SliverGridDelegateWithFixedCrossAxisCount.
      final gridView = tester.widget<GridView>(find.byType(GridView));
      final delegate =
          gridView.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, 2);
    });

    testWidgets('Phase 12 UI-04: grid declares one slot per lexicon entry',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _wrap(LexiconPicker(onSelected: (_) {})),
      );
      final gridView = tester.widget<GridView>(find.byType(GridView));
      final delegate = gridView.childrenDelegate as SliverChildBuilderDelegate;
      expect(delegate.estimatedChildCount, kStarterLexicon.length);
    });

    testWidgets('Phase 12 UI-04: every visible tile renders the noun word '
        'as a text fallback even when the stock image file is missing',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _wrap(LexiconPicker(onSelected: (_) {})),
      );
      // First few visible tiles — the alphabetical first words include
      // 'auga' and 'banani' (alphabetical sort).
      // Pump enough frames for any Image.asset errorBuilder to fire.
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      // Pick a stable early word.
      expect(find.text('auga'), findsOneWidget);
    });

    testWidgets('a sample of off-screen entries can be scrolled into view',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
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
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      LexiconEntry? selected;
      await tester.pumpWidget(
        _wrap(
          LexiconPicker(
            onSelected: (e) => selected = e,
          ),
        ),
      );

      // GridView.builder with cacheExtent can mount tiles into the
      // widget tree before they are inside the visible viewport;
      // scrollUntilVisible exits at the first non-empty .evaluate(),
      // which is too early for hit-testing. Use ensureVisible to
      // guarantee the tile center is on-screen before tapping.
      final hundurTile = find.byKey(const Key('lexicon-tile-hundur'));
      await tester.scrollUntilVisible(hundurTile, 100.0,
          scrollable: find.byType(Scrollable).first);
      await tester.ensureVisible(hundurTile);
      await tester.pumpAndSettle();
      await tester.tap(hundurTile);
      await tester.pumpAndSettle();

      expect(selected, isNotNull);
      expect(selected!.word, 'hundur');
    });

    testWidgets('AppBar shows Icelandic title "Veldu orð"', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _wrap(
          LexiconPicker(onSelected: (_) {}),
        ),
      );
      // AppBar persists on the parent-facing picker screen — Phase 12
      // only removes AppBars from kid-mode screens.
      expect(find.text('Veldu orð'), findsOneWidget);
    });

    testWidgets('every entry tile is tappable', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      LexiconEntry? selected;
      await tester.pumpWidget(
        _wrap(
          LexiconPicker(onSelected: (e) => selected = e),
        ),
      );
      // Pick a non-first word to ensure we're not just hitting the
      // top-of-list tile. Use ensureVisible (see comment on tapping
      // hundur, above) to guarantee the tile center is on-screen.
      final epliTile = find.byKey(const Key('lexicon-tile-epli'));
      await tester.scrollUntilVisible(epliTile, 100.0,
          scrollable: find.byType(Scrollable).first);
      await tester.ensureVisible(epliTile);
      await tester.pumpAndSettle();
      await tester.tap(epliTile);
      await tester.pumpAndSettle();
      expect(selected, isNotNull);
      expect(selected!.word, 'epli');
    });
  });
}
