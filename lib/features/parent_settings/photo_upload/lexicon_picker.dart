// Phase 10 Plan 04 — LexiconPicker.
// Phase 12 Plan UI-04 — picker becomes a 2-column image grid.
//
// Parent-facing screen showing the curated kStarterLexicon as a 2-column
// scrollable image grid (alphabetically sorted). Each tile shows the
// entry's stock image at top + the noun word as a caption beneath. When
// the stock image asset is missing on disk (Phase 11 ships them
// asynchronously), the tile falls back to a colored pastel square + the
// noun text only — never a broken-image icon.
//
// Tap a tile to select a word. The screen does not pop itself; the caller
// decides what to do after `onSelected` fires (the upload flow pops +
// invokes the repository). This keeps LexiconPicker decoupled from the
// navigation surface so it stays unit-testable.
//
// Icelandic AppBar title: "Veldu orð" (Choose word). The AppBar persists
// because this is a parent-facing screen — Phase 12's AppBar removal
// only applies to kid-mode surfaces.

import 'package:flutter/material.dart';

import '../../../core/lexicon/lexicon.dart';
import '../../../core/lexicon/lexicon_entry.dart';
import '../../stafir/widgets/letter_tile_palette.dart';

class LexiconPicker extends StatelessWidget {
  const LexiconPicker({super.key, required this.onSelected});

  final void Function(LexiconEntry entry) onSelected;

  @override
  Widget build(BuildContext context) {
    final sorted = List<LexiconEntry>.from(kStarterLexicon)
      ..sort((a, b) => a.word.compareTo(b.word));
    return Scaffold(
      appBar: AppBar(title: const Text('Veldu orð')),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          // Slightly taller than wide — leaves room for image + caption.
          childAspectRatio: 0.85,
        ),
        itemCount: sorted.length,
        itemBuilder: (context, i) => _LexiconTile(
          key: Key('lexicon-tile-${sorted[i].word}'),
          entry: sorted[i],
          onTap: () => onSelected(sorted[i]),
          fallbackColorIndex: i,
        ),
      ),
    );
  }
}

/// One tile in the picker grid. Renders the lexicon entry's stock image
/// in the upper portion and the noun word as a caption beneath. If the
/// image asset is missing on disk, falls back to a pastel square (so the
/// parent never sees a broken-image icon) — the noun word stays visible
/// either way.
class _LexiconTile extends StatelessWidget {
  const _LexiconTile({
    super.key,
    required this.entry,
    required this.onTap,
    required this.fallbackColorIndex,
  });

  final LexiconEntry entry;
  final VoidCallback onTap;

  /// Pastel index for the fallback background when the image is missing.
  /// We just rotate through the locked LetterTile palette so the picker
  /// has consistent visual identity with Stafir tiles.
  final int fallbackColorIndex;

  @override
  Widget build(BuildContext context) {
    final fallbackColor = paletteForIndex(fallbackColorIndex);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline,
            width: 1.5,
          ),
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.asset(
                  entry.defaultImagePath,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) => Container(
                    color: fallbackColor,
                    alignment: Alignment.center,
                    // Fallback = pastel block. The noun word still
                    // appears in the caption row below; we keep the
                    // image area clean so the eye is drawn down.
                    child: const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                entry.word,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
