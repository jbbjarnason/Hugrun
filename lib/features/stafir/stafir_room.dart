import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/alphabet/icelandic_letter.dart';
import '../../core/audio/audio_engine_provider.dart';
import '../../core/audio/utterance_resolver.dart';
import 'example_word_resolver.dart';
import 'widgets/example_word_overlay.dart';
import 'widgets/letter_grid.dart';

/// Phase 4 D-09 / D-10 / D-13 / STAFIR-01..10. Replaces the Phase 1
/// placeholder.
///
/// MANIFEST SWAP-IN NOTE (D-22, D-23):
///   Phase 4 ships against the Phase 2 stub manifest (5 clips).
///   When Phase 3 ships the regenerated audio_manifest.g.dart with all
///   32 letter-name + 32 example-word entries:
///     1. Phase 3 commits the new audio_manifest.g.dart + assets.
///     2. Open lib/features/stafir/example_word_resolver.dart.
///     3. Extend the switch in letterToUtteranceKey to return the new
///        enum values for all 32 slugs.
///     4. Populate kLetterToWord in lib/core/audio/utterance_resolver.dart
///        with the 32 (letterX → wordY) pairings.
///     5. Run `flutter test` to confirm. Run on a device and tap each letter.
///   No StafirRoom code changes required.
class StafirRoom extends ConsumerStatefulWidget {
  const StafirRoom({super.key});

  @override
  ConsumerState<StafirRoom> createState() => _StafirRoomState();
}

class _StafirRoomState extends ConsumerState<StafirRoom> {
  final ExampleWordOverlayController _overlayCtl =
      ExampleWordOverlayController();

  @override
  void dispose() {
    _overlayCtl.dispose();
    super.dispose();
  }

  void _onLetterTap(IcelandicLetter letter) {
    final key = letterToUtteranceKey(letter.assetSlug);
    if (key == null) {
      // Phase 2 stub: enum entry doesn't exist for this letter. Visual
      // feedback already happened via LetterTile onTapDown. No audio.
      // Phase 3 fixes by extending letterToUtteranceKey + the manifest.
      return;
    }
    // Fire-and-forget. AudioEngine.play handles cancel-on-retap.
    unawaited(ref.read(audioEngineProvider).play(key));
    // Show example-word overlay only if a paired word exists in the
    // active manifest.
    final resolved = resolveLetterToClips(key);
    final wordKey = resolved.wordKey;
    if (wordKey != null) {
      _overlayCtl.show(slugFromWordKey(wordKey));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppBar kept for nav parity with Phase 1 (back button); behind
      // immersive system UI mode (Plan 01) so chrome is minimal in
      // practice on hardware.
      appBar: AppBar(title: const Text('Stafir')),
      body: SafeArea(
        child: Stack(
          children: <Widget>[
            LetterGrid(onLetterTap: _onLetterTap),
            IgnorePointer(
              child: ExampleWordOverlay(controller: _overlayCtl),
            ),
          ],
        ),
      ),
    );
  }
}
