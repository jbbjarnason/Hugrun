// CVC blending activity widget (Phase 6 Plan 06-02 Workstream B).
//
// Decisions exercised:
//   D-08   Reuses Phase 5 mode-toggle pattern; lives at lib/features/stafir/
//          cvc/ parallel to matching/.
//   D-09   Round shows the word's image at top + 3 LetterTiles in a row
//          representing c1, v, c2.
//   D-10   Tap order plays per-letter phoneme; after 3 taps the blend plays.
//   D-11   SOFT ORDER — child can tap any letter first; the blend fires
//          once all 3 are tapped, regardless of order.
//   D-12   Already-tapped letters get a subtle visual cue (lower opacity).
//   D-13   ~2s pause after blend, then auto-advance to a new round.
//   D-14   Re-tapping an already-tapped letter replays its phoneme. The
//          blend itself does NOT re-fire while the round is in its
//          post-blend wait state.
//   D-21   Missing-clip silent fallback (AudioEngine.play returns silently
//          when kAudioManifest[key] == null). Phase 6 ships unreviewed
//          phoneme keys; until the review pass repopulates the Dart manifest,
//          the activity is structurally functional but plays no sound.
//
// Reuses (no duplicate widgets):
//   - LetterTile (Phase 4)
//   - AudioEngine via audioEngineProvider (Phase 4)
//   - kIcelandicAlphabet (Phase 2) for tile palette indexing

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/alphabet/alphabet.dart';
import '../../../core/alphabet/icelandic_letter.dart';
import '../../../core/audio/audio_engine_provider.dart';
import '../../../core/cvc/cvc_word.dart';
import '../../../core/cvc/phoneme_resolver.dart';
import '../../../core/lexicon/icelandic_slug.dart';
import '../example_word_resolver.dart';
import '../widgets/letter_tile.dart';
import 'cvc_providers.dart';

class CvcActivity extends ConsumerStatefulWidget {
  const CvcActivity({super.key});

  @override
  ConsumerState<CvcActivity> createState() => _CvcActivityState();
}

class _CvcActivityState extends ConsumerState<CvcActivity> {
  /// The set of letter glyphs the child has tapped this round. We key on
  /// position-in-CVC (0/1/2) rather than glyph because the same letter can
  /// appear twice (e.g. some hypothetical "sus"). No CVC starter ships with
  /// a duplicate so this is defensive.
  final Set<int> _tappedPositions = <int>{};

  /// Once true, blend has played. Re-taps replay phonemes but do NOT
  /// re-fire the blend (D-14 + C9).
  bool _blendPlayed = false;

  Timer? _advanceTimer;

  /// Auto-advance delay after blend plays (D-13). The activity widget
  /// re-randomizes the cvcCurrentWordProvider after this delay.
  static const Duration _advanceDelay = Duration(seconds: 2);

  @override
  void dispose() {
    _advanceTimer?.cancel();
    super.dispose();
  }

  void _onLetterTap(CvcWord word, int position, IcelandicLetter letter) {
    final phonemeKey = phonemeKeyForSlug(letter.assetSlug);
    final engine = ref.read(audioEngineProvider);

    // 1. Always play the per-letter phoneme (D-14 replay-on-retap).
    if (phonemeKey != null) {
      unawaited(engine.play(phonemeKey));
    }

    // 2. If round is past completion, do not advance state again.
    if (_blendPlayed) return;

    // 3. Mark this position tapped.
    setState(() => _tappedPositions.add(position));

    // 4. If all 3 positions tapped, fire the blend.
    if (_tappedPositions.length == 3) {
      unawaited(engine.play(word.wordClip));
      setState(() => _blendPlayed = true);
      _advanceTimer?.cancel();
      _advanceTimer = Timer(_advanceDelay, _resetRound);
    }
  }

  void _resetRound() {
    if (!mounted) return;
    setState(() {
      _tappedPositions.clear();
      _blendPlayed = false;
    });
    // Pick a new word. Since cvcCurrentWordProvider is keepAlive + computes
    // at first watch, we invalidate to force a re-pick.
    ref.invalidate(cvcCurrentWordProvider);
  }

  @override
  Widget build(BuildContext context) {
    final word = ref.watch(cvcCurrentWordProvider);
    return LayoutBuilder(
      builder: (context, constraints) {
        final imageHeight = constraints.maxHeight * 0.55;
        return Column(
          children: <Widget>[
            SizedBox(
              height: imageHeight,
              child: _CvcRoundImage(word: word),
            ),
            const SizedBox(height: 16),
            Expanded(child: _buildTilesRow(word)),
          ],
        );
      },
    );
  }

  Widget _buildTilesRow(CvcWord word) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: <Widget>[
        for (int i = 0; i < word.letters.length; i++)
          SizedBox(
            width: 160,
            child: Opacity(
              // D-12: already-tapped letters get a subtle visual cue.
              // 1.0 untapped, 0.55 tapped — visible enough to read but
              // clearly differentiated.
              opacity: _tappedPositions.contains(i) ? 0.55 : 1.0,
              child: LetterTile(
                key: Key('cvc-tile-$i-${word.letters[i].assetSlug}'),
                letter: word.letters[i],
                letterIndex:
                    kIcelandicAlphabet.indexOf(word.letters[i]),
                minSize: 0,
                onLetterTap: (l) => _onLetterTap(word, i, l),
              ),
            ),
          ),
      ],
    );
  }
}

/// Inline image area for the CVC round. Mirrors MatchingRoundImage's
/// pattern: try the Phase 11 lexicon image at
/// `assets/images/letters/words/<slug>.webp`, fall back to a text-on-color
/// tile when the asset is missing (e.g. `hár`/`gás` aren't in the starter
/// lexicon yet). Slug is derived from `word.word` via the ASCII
/// transliteration helper so `hús` → `hus.webp`, `kýr` → `kyr.webp`, etc.
class _CvcRoundImage extends StatelessWidget {
  const _CvcRoundImage({required this.word});

  final CvcWord word;

  @override
  Widget build(BuildContext context) {
    final slug = icelandicWordToSlug(word.word);
    final imagePath = exampleWordImagePath(slug);
    return LayoutBuilder(
      builder: (context, constraints) => Center(
        child: Container(
          key: Key('cvc-round-image-${word.word}'),
          width: constraints.maxWidth * 0.8,
          constraints: const BoxConstraints(minHeight: 240),
          decoration: BoxDecoration(
            color: const Color(0xFFFCE4A6),
            borderRadius: BorderRadius.circular(24),
          ),
          alignment: Alignment.center,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Image.asset(
              imagePath,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stack) => Text(
                word.word,
                style: const TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
