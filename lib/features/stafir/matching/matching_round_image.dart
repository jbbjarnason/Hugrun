// Renders the image area of a matching round (Phase 5 Plan 05-02).
//
// Decisions exercised:
//   D-12  Phase 5 ships text-on-color placeholder for stock images
//         (consistent with example_word_overlay's placeholder pattern).
//         Real custom illustrations come in a polish pass or via Phase 10
//         personalization.
//   D-13  PhotoOverride is wired through but Phase 5 renders a labeled
//         placeholder; Phase 10 fills in real photo loading.
//   D-14  Image fills the upper area of the screen — caller controls the
//         outer SizedBox; this widget only fills its given bounds.
//
// Dimensioning: width = 80% of parent maxWidth; minHeight = 240 logical px.
// Single Text child = the slug or photoId label.

import 'package:flutter/material.dart';

import '../../../core/matching/matching_round.dart';

/// Renders the image area for the current matching round.
class MatchingRoundImage extends StatelessWidget {
  const MatchingRoundImage({super.key, required this.round});

  final MatchingRound round;

  @override
  Widget build(BuildContext context) {
    final src = round.imageSource;
    final String label;
    final Key markerKey;
    switch (src) {
      case StockPlaceholder(wordSlug: final slug):
        label = slug;
        markerKey = Key('matching-stock-placeholder-${round.targetWordSlug}');
      case PhotoOverride(photoId: final id):
        label = id;
        markerKey = Key('matching-photo-override-$id');
    }

    return LayoutBuilder(
      builder: (context, constraints) => Center(
        child: Container(
          key: markerKey,
          width: constraints.maxWidth * 0.8,
          constraints: const BoxConstraints(minHeight: 240),
          decoration: BoxDecoration(
            // Soft warm placeholder color — same family as the letter-tile
            // palette (Phase 4) but neutral so it doesn't compete with
            // the option tiles below.
            color: const Color(0xFFFCE4A6),
            borderRadius: BorderRadius.circular(24),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 56,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
            ),
          ),
        ),
      ),
    );
  }
}
