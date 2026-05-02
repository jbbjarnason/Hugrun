// NumberTile — Phase 8 Plan 08-02 mirror of Phase 4's LetterTile.
//
// Decisions:
//   D-01  10 NumberTiles render in a 2×5 grid (landscape) in the Tölur
//         room. Same locked pastel palette as Phase 4, same animation,
//         same tap-target sizing, same onTapDown synchronous feedback —
//         the only structural difference vs LetterTile is the data type
//         (IcelandicNumber vs IcelandicLetter) and what glyph is rendered
//         (digit string vs letter character).
//   D-02  The tile itself stays "dumb" — no Riverpod, no AudioEngine
//         knowledge. TolurRoom composes the grid and wires the
//         onNumberTap callback to AudioEngine.play via numberAudioKey.
//   D-03  Synchronous visual feedback (mirrors STAFIR-06): scale animation
//         fires on onTapDown, not onTap.
//
// Why not extract a shared base widget?
//   - The mirror cost is small (~40 effective LOC of widget tree).
//   - Extracting a generic <T> tile would couple Stafir + Tölur into a
//     shared widget; later UI tuning per room would have to thread typed
//     parameters through the base. Keeping LetterTile + NumberTile as
//     separate concrete widgets keeps each room's evolution independent.
//
// Layout proxy: minSize=200 logical-px, mirrored from STAFIR-01. On
// typical tablets this resolves to ≈3.85 cm physical. NumberGrid
// overrides minSize to 0 so the grid math controls dimensions.

import 'package:flutter/material.dart';

import '../../../core/numbers/icelandic_number.dart';
import '../../stafir/widgets/letter_tile_palette.dart';

/// A single tappable digit card. Mirror of [LetterTile] with one Text widget
/// (the digit glyph) and the same scale-animation gesture contract.
class NumberTile extends StatefulWidget {
  const NumberTile({
    super.key,
    required this.number,
    required this.numberIndex,
    required this.onNumberTap,
    this.minSize = 200,
  });

  /// The numeral to render. The tile shows [IcelandicNumber.value] as a
  /// decimal digit string (e.g. "1".."10"). Audio variants live on the
  /// model; the resolver wires them to UtteranceKeys upstream.
  final IcelandicNumber number;

  /// Position in the rendered grid — drives [paletteForIndex] color
  /// selection. TolurRoom passes the kIcelandicNumbers index (0..9).
  final int numberIndex;

  /// Invoked synchronously on tap-down. The callback receives the [number]
  /// so callers don't need to track index/value mapping.
  final ValueChanged<IcelandicNumber> onNumberTap;

  /// Minimum logical-px size. NumberGrid overrides to 0 because the grid
  /// math handles tile dimensions.
  final double minSize;

  @override
  State<NumberTile> createState() => _NumberTileState();
}

class _NumberTileState extends State<NumberTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scaleCtl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    // Same 200ms ease-out cycle as LetterTile (D-30 Phase 4 / D-01 Phase 8).
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
    // D-03: callback fires first (synchronous), then animation runs.
    widget.onNumberTap(widget.number);
    _scaleCtl.reverse().then((_) {
      if (mounted) _scaleCtl.forward();
    });
  }

  @override
  Widget build(BuildContext context) {
    final color = paletteForIndex(widget.numberIndex);
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
              '${widget.number.value}',
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
