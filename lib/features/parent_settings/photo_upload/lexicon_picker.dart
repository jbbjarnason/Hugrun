// Phase 10 Plan 04 — LexiconPicker.
//
// Parent-facing screen showing the curated kStarterLexicon as a scrollable
// alphabetical list. Tap a tile to select a word. The screen does not pop
// itself; the caller decides what to do after `onSelected` fires (the upload
// flow pops + invokes the repository). This decouples LexiconPicker from
// the navigation surface so it stays unit-testable.
//
// Icelandic AppBar title: "Veldu orð" (Choose word).

import 'package:flutter/material.dart';

import '../../../core/lexicon/lexicon.dart';
import '../../../core/lexicon/lexicon_entry.dart';

class LexiconPicker extends StatelessWidget {
  const LexiconPicker({super.key, required this.onSelected});

  final void Function(LexiconEntry entry) onSelected;

  @override
  Widget build(BuildContext context) {
    final sorted = List<LexiconEntry>.from(kStarterLexicon)
      ..sort((a, b) => a.word.compareTo(b.word));
    return Scaffold(
      appBar: AppBar(title: const Text('Veldu orð')),
      body: ListView.builder(
        itemCount: sorted.length,
        itemBuilder: (context, i) {
          final entry = sorted[i];
          return ListTile(
            key: Key('lexicon-tile-${entry.word}'),
            title: Text(
              entry.word,
              style: const TextStyle(fontSize: 24),
            ),
            onTap: () => onSelected(entry),
          );
        },
      ),
    );
  }
}
