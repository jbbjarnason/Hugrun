import 'package:flutter/material.dart';

import '../../../core/alphabet/icelandic_letter.dart';
import 'letter_tile_palette.dart';

/// A single tappable letter card. Phase 4 D-10 / D-13 / D-30.
///
/// Contracts (STAFIR-01, -06, -07, -08):
/// - **Synchronous visual feedback (STAFIR-06):** the scale animation fires
///   on `onTapDown`, NOT on `onTap`. The child sees a reaction the same
///   frame the gesture is detected, independent of audio readiness. The
///   `onLetterTap` callback is invoked at the same moment so the audio
///   pipeline (Plan 04-04) can dispatch in parallel.
/// - **Tap target ≥2 cm × 2 cm physical (STAFIR-01):** enforced via the
///   `minSize` constraint. 200 logical px is the proxy floor; on typical
///   tablets at DPR 2.0 (~264 dpi) this resolves to ≈3.85 cm physical.
/// - **No failure UI (STAFIR-07):** widget tree contains no error/check/
///   close icons. Wrong taps in Phase 4 are no-ops, not failures.
/// - **No text instructions (STAFIR-08):** widget tree contains exactly
///   one Text widget — the letter glyph. No labels, no hints, no name.
/// - **No selected state (D-13):** post-tap, the visual returns to neutral.
///   No "stars on letters seen" or any score-like UI.
///
/// LetterTile is a "dumb" leaf widget — it has no Riverpod dependency and
/// no AudioEngine knowledge. Plan 04-04's StafirRoom composes the grid and
/// wires the `onLetterTap` callback to AudioEngine.play().
class LetterTile extends StatefulWidget {
  const LetterTile({
    super.key,
    required this.letter,
    required this.letterIndex,
    required this.onLetterTap,
    this.minSize = 200,
  });

  /// The letter to render. Glyph is what's shown; name + assetSlug are NOT
  /// displayed (STAFIR-08).
  final IcelandicLetter letter;

  /// Position in the rendered alphabet — drives [paletteForIndex] color
  /// selection. Plan 04-04 passes the kIcelandicAlphabet index.
  final int letterIndex;

  /// Invoked synchronously on tap-down (STAFIR-06). The callback receives
  /// the [letter] so callers don't need to track index/letter mapping.
  final ValueChanged<IcelandicLetter> onLetterTap;

  /// Minimum logical-px size (D-09 proxy for ≥2 cm physical). Plan 04-04's
  /// LetterGrid uses GridView sizing and overrides this to 0 because the
  /// grid math handles tile dimensions.
  final double minSize;

  @override
  State<LetterTile> createState() => _LetterTileState();
}

class _LetterTileState extends State<LetterTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scaleCtl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    // 200 ms ease-out per D-30. The animation runs forward to 1.0 (rest)
    // initially. On tap-down we reverse to 0.9 (squeeze) then forward back
    // to 1.0 (release).
    _scaleCtl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      reverseDuration: const Duration(milliseconds: 200),
      lowerBound: 0.9,
      upperBound: 1.0,
      value: 1.0,
    );
    _scale = CurvedAnimation(parent: _scaleCtl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _scaleCtl.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) {
    // STAFIR-06: callback first, animation second. The callback is
    // fire-and-forget; LetterTile doesn't await it. The squeeze-then-
    // bounce-back animation runs entirely in the AnimationController and
    // is independent of the callback's completion (which may be running
    // a slow audio dispatch on the AudioEngine).
    widget.onLetterTap(widget.letter);
    // reverse() drives toward lowerBound (0.9 — the squeeze).
    // The .then() chains forward() to drive back to upperBound (1.0).
    // Plan 04-04 may extend this pattern; for now this is the entire
    // tap interaction.
    _scaleCtl.reverse().then((_) {
      if (mounted) _scaleCtl.forward();
    });
  }

  @override
  Widget build(BuildContext context) {
    final color = paletteForIndex(widget.letterIndex);
    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: widget.minSize,
        minHeight: widget.minSize,
      ),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) =>
            Transform.scale(scale: _scale.value, child: child),
        child: GestureDetector(
          onTapDown: _handleTapDown,
          behavior: HitTestBehavior.opaque,
          child: Container(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(24),
            ),
            alignment: Alignment.center,
            child: Text(
              widget.letter.glyph,
              // SF Pro on iOS, Roboto on Android (Flutter's default
              // sans-serif) per D-30. Letter glyph is the only Text widget
              // in the tile per STAFIR-08.
              style: const TextStyle(
                fontSize: 96,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
