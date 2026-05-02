// Phase 12 UI-03 — pre-reader-friendly glyphs for the two HomePage room
// buttons. Each glyph is a styled motif of the room's primary content:
//
//   StafirRoomGlyph — three Icelandic letters "Aa á" rendered large in
//                     a chunky kid-friendly weight, on the locked
//                     pastel palette.
//   TolurRoomGlyph  — three numerals "1 2 3" rendered the same way.
//
// Pure StatelessWidgets. No state, no audio, no Riverpod scope. The
// widgets are slot-rendered into RoomButton.glyph by HomePage.
//
// The Key keys (`home-room-glyph-stafir` / `home-room-glyph-tolur`) are
// public contract — widget tests in test/features/home/home_page_test.dart
// look them up.

import 'package:flutter/material.dart';

import '../stafir/widgets/letter_tile_palette.dart';

/// Big "Aa á" glyph for the Stafir (letters) room button.
///
/// Dominant visual cue for a 5-year-old who can't read. Three glyphs
/// from the Icelandic alphabet (uppercase + lowercase + accented)
/// rendered side by side in pastel colors that match the LetterTile
/// palette (so the room's visual identity carries from the home screen
/// into the activity surface).
class StafirRoomGlyph extends StatelessWidget {
  const StafirRoomGlyph({super.key = const Key('home-room-glyph-stafir')});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _Glyph(
          char: 'A',
          color: paletteForIndex(0), // dusty peach
        ),
        const SizedBox(width: 6),
        _Glyph(
          char: 'a',
          color: paletteForIndex(2), // dusty mint
        ),
        const SizedBox(width: 6),
        _Glyph(
          char: 'á',
          color: paletteForIndex(4), // dusty periwinkle
        ),
      ],
    );
  }
}

/// Big "1 2 3" glyph for the Tölur (numbers) room button.
class TolurRoomGlyph extends StatelessWidget {
  const TolurRoomGlyph({super.key = const Key('home-room-glyph-tolur')});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _Glyph(
          char: '1',
          color: paletteForIndex(1), // dusty butter
        ),
        const SizedBox(width: 6),
        _Glyph(
          char: '2',
          color: paletteForIndex(3), // dusty sky-teal
        ),
        const SizedBox(width: 6),
        _Glyph(
          char: '3',
          color: paletteForIndex(5), // dusty lavender
        ),
      ],
    );
  }
}

/// One large character chip — pastel circular background with the glyph
/// rendered in dark on top. Sized for legibility at home-screen distance
/// on a tablet held in the lap.
class _Glyph extends StatelessWidget {
  const _Glyph({required this.char, required this.color});

  final String char;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      alignment: Alignment.center,
      child: Text(
        char,
        style: const TextStyle(
          fontSize: 44,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1A1A1A),
          height: 1.0,
        ),
      ),
    );
  }
}
