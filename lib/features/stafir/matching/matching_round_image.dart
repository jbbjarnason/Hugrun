// Renders the image area of a matching round (Phase 5 Plan 05-02).
//
// Decisions exercised:
//   D-12  Phase 5 shipped a text-on-color placeholder for stock images.
//         Phase 11 then baked 32 lexicon images into
//         `assets/images/letters/words/<slug>.webp` so this widget now
//         renders the real Image.asset when it exists, falling back to
//         the original text-on-color tile when the asset is missing
//         (e.g. word slugs from the audio manifest that have no
//         lexicon image yet, like `wordHar` / `wordGas`). The fallback
//         path mirrors ExampleWordOverlay's behavior (Phase 4 D-12) and
//         the Tölur correspondence/addition activities (Phase 9).
//   D-13  PhotoOverride is wired through but renders a labeled
//         placeholder; Phase 10 personalization fills in real photo
//         loading from the photoId.
//   D-14  Image fills the upper area of the screen — caller controls the
//         outer SizedBox; this widget only fills its given bounds.
//
// Dimensioning: width = 80% of parent maxWidth; minHeight = 240 logical px.
// When the asset exists, the Image fills the rounded container with
// BoxFit.contain so the whole illustration is visible without cropping.

import 'package:flutter/material.dart';

import '../../../core/matching/matching_round.dart';
import '../example_word_resolver.dart';

/// Renders the image area for the current matching round.
class MatchingRoundImage extends StatelessWidget {
  const MatchingRoundImage({super.key, required this.round});

  final MatchingRound round;

  @override
  Widget build(BuildContext context) {
    final src = round.imageSource;
    final String label;
    final Key markerKey;
    // For StockPlaceholder rounds, attempt to load the lexicon image at
    // assets/images/letters/words/<slug>.webp. Phase 11 baked 32 such
    // images; if the slug has no image (e.g. letter-name words like
    // `a`, `b`, ... derived from `wordA`/`wordB` audio keys), errorBuilder
    // falls back to the original text-on-color tile.
    String? imagePath;
    switch (src) {
      case StockPlaceholder(wordSlug: final slug):
        label = slug;
        markerKey = Key('matching-stock-placeholder-${round.targetWordSlug}');
        imagePath = exampleWordImagePath(slug);
      case PhotoOverride(photoId: final id):
        label = id;
        markerKey = Key('matching-photo-override-$id');
        // Photo personalization is Phase 10's job — keep the labeled
        // placeholder until real photo loading lands.
        imagePath = null;
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
            // the option tiles below. Visible behind transparent areas
            // of the lexicon image.
            color: const Color(0xFFFCE4A6),
            borderRadius: BorderRadius.circular(24),
          ),
          alignment: Alignment.center,
          child: imagePath != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.asset(
                    imagePath,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stack) =>
                        _PlaceholderText(label: label),
                  ),
                )
              : _PlaceholderText(label: label),
        ),
      ),
    );
  }
}

/// Text-on-color fallback rendered when the lexicon image is missing
/// (or for PhotoOverride rounds until Phase 10 ships).
class _PlaceholderText extends StatelessWidget {
  const _PlaceholderText({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 56,
        fontWeight: FontWeight.w600,
        color: Color(0xFF1A1A1A),
      ),
    );
  }
}
