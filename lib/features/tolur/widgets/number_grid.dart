// 10-tile NumberGrid for the Tölur room. Phase 8 Plan 08-02 D-01.
//
// Mirrors Phase 4's LetterGrid in structure: GridView.builder over a const
// list (kIcelandicNumbers vs kIcelandicAlphabet), with a per-orientation
// crossAxisCount.
//
// Layout:
//   - Landscape (default — orientation locked by Phase 4 D-15): 5 cols ×
//     2 rows. The 2×5 shape gives generous tile size on a 1280×800 tablet
//     and reads naturally left-to-right top-to-bottom for digits 1..10.
//   - Portrait (defensive — locked orientation should prevent it, but
//     widget tests run portrait): 2 cols × 5 rows.

import 'package:flutter/material.dart';

import '../../../core/numbers/icelandic_number.dart';
import '../../../core/numbers/numbers.dart';
import 'number_tile.dart';

class NumberGrid extends StatelessWidget {
  const NumberGrid({super.key, required this.onNumberTap});

  final ValueChanged<IcelandicNumber> onNumberTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isLandscape = constraints.maxWidth > constraints.maxHeight;
        final crossAxisCount = isLandscape ? 5 : 2;
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1,
          ),
          itemCount: kIcelandicNumbers.length,
          itemBuilder: (context, index) {
            final number = kIcelandicNumbers[index];
            return NumberTile(
              key: Key('number-tile-$index-${number.value}'),
              number: number,
              numberIndex: index,
              onNumberTap: onNumberTap,
              minSize: 0, // grid handles sizing
            );
          },
        );
      },
    );
  }
}
