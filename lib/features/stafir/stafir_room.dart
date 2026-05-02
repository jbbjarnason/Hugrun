import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/alphabet/icelandic_letter.dart';
import '../../core/audio/audio_engine_provider.dart';
import '../../core/audio/utterance_resolver.dart';
import 'example_word_resolver.dart';
import 'matching/matching_activity.dart';
import 'stafir_mode.dart';
import 'widgets/example_word_overlay.dart';
import 'widgets/letter_grid.dart';
import 'widgets/stafir_mode_toggle.dart';

/// Phase 4 D-09 / D-10 / D-13 / STAFIR-01..10. Plan 05-03 adds the
/// Letters / Match mode toggle (D-01).
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
  ConsumerState<StafirRoom> createState() => StafirRoomState();
}

/// Public so widget tests can access via `tester.state<StafirRoomState>(...)`
/// to drive [debugSetMode] (Plan 05-03 Task 2).
class StafirRoomState extends ConsumerState<StafirRoom> {
  final ExampleWordOverlayController _overlayCtl =
      ExampleWordOverlayController();

  StafirMode _mode = StafirMode.letters;

  /// Test-only escape hatch to drive the mode without simulating a 3-second
  /// hold gesture. The toggle widget itself is exercised by its own widget
  /// tests; this lets the StafirRoom tests stay focused on body composition.
  @visibleForTesting
  void debugSetMode(StafirMode m) => setState(() => _mode = m);

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
      return;
    }
    unawaited(ref.read(audioEngineProvider).play(key));
    final resolved = resolveLetterToClips(key);
    final wordKey = resolved.wordKey;
    if (wordKey != null) {
      _overlayCtl.show(slugFromWordKey(wordKey));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Stafir')),
      body: SafeArea(
        child: Stack(
          children: <Widget>[
            // Mode-conditional primary surface.
            switch (_mode) {
              StafirMode.letters => LetterGrid(onLetterTap: _onLetterTap),
              StafirMode.match => const MatchingActivity(),
            },
            // Letters-mode-only example word overlay.
            if (_mode == StafirMode.letters)
              IgnorePointer(
                child: ExampleWordOverlay(controller: _overlayCtl),
              ),
            // Mode toggle, top-right corner. 3-second hold is required
            // to swap modes (D-01 — kid-safe, accident-resistant).
            Positioned(
              top: 8,
              right: 8,
              child: StafirModeToggle(
                currentMode: _mode,
                onToggle: () =>
                    setState(() => _mode = _mode.next),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
