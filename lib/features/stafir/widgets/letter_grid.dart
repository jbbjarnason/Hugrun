import 'package:flutter/material.dart';

import '../../../core/alphabet/alphabet.dart';
import '../../../core/alphabet/icelandic_letter.dart';
import 'letter_tile.dart';

/// 32-tile grid in MMS order. Plan 04-04 D-09.
///
/// Layout:
/// - Landscape (orientation locked by Plan 04-01): 4 rows × 8 cols
/// - Portrait (defensive — locked orientation should prevent this in
///   production, but tests run portrait): 8 rows × 4 cols
///
/// Each tile is a [LetterTile]; tap dispatches to [onLetterTap] which
/// upstream wires to AudioEngine.play.
class LetterGrid extends StatelessWidget {
  const LetterGrid({super.key, required this.onLetterTap});

  final ValueChanged<IcelandicLetter> onLetterTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isLandscape = constraints.maxWidth > constraints.maxHeight;
        final crossAxisCount = isLandscape ? 8 : 4;
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1,
          ),
          itemCount: kIcelandicAlphabet.length,
          itemBuilder: (context, index) {
            final letter = kIcelandicAlphabet[index];
            return LetterTile(
              key: Key('letter-tile-$index-${letter.assetSlug}'),
              letter: letter,
              letterIndex: index,
              onLetterTap: onLetterTap,
              minSize: 0, // grid handles sizing
            );
          },
        );
      },
    );
  }
}
