// Tölur (Numbers) room. Phase 8 Plans 08-02 + 08-04 + Phase 9 Plan 09-04.
//
// Hosts two child surfaces switched via a 3-second-hold mode toggle:
//   - TapToHear (default): 10 NumberTiles, tap to play numeral audio
//   - Activity: ActivityRotator picks one of {Sequencing, Correspondence,
//               Subitizing, Addition} per round (Phase 9 D-15).
//
// Mirror of StafirRoom's mode-switch pattern (Phase 5 D-01 / Phase 6 D-15):
// the toggle widget lives top-right; the body uses a switch-on-enum.
//
// Manifest swap-in: like Phase 4 + Phase 6, the 18 numeral keys ship in
// the enum but are absent from kAudioManifest until the audio review
// pass regenerates lib/gen/audio_manifest.g.dart. AudioEngine.play()
// silently no-ops on missing entries (Phase 4 D-22, D-23). The visual
// feedback fires regardless via NumberTile's onTapDown animation.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audio/audio_engine_provider.dart';
import '../../core/numbers/gender.dart';
import '../../core/numbers/icelandic_number.dart';
import '../../core/numbers/number_audio_resolver.dart';
import 'activity_rotator.dart';
import 'tolur_mode.dart';
import 'widgets/number_grid.dart';
import 'widgets/tolur_mode_toggle.dart';

class TolurRoom extends ConsumerStatefulWidget {
  const TolurRoom({super.key});

  @override
  ConsumerState<TolurRoom> createState() => TolurRoomState();
}

/// Public so widget tests + integration tests can drive [debugSetMode]
/// without simulating a 3-second hold gesture (mirrors StafirRoomState).
class TolurRoomState extends ConsumerState<TolurRoom> {
  TolurMode _mode = TolurMode.tapToHear;

  @visibleForTesting
  TolurMode get debugMode => _mode;

  @visibleForTesting
  void debugSetMode(TolurMode m) => setState(() => _mode = m);

  void _onNumberTap(IcelandicNumber number) {
    // D-02 / D-03: abstract counting uses masculine (NUM-03). Phase 9 will
    // route picture-object counting through the depicted noun's gender via
    // the same numberAudioKey resolver.
    final key = numberAudioKey(number.value, Gender.masculine);
    unawaited(ref.read(audioEngineProvider).play(key));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tölur')),
      body: SafeArea(
        child: Stack(
          children: <Widget>[
            switch (_mode) {
              TolurMode.tapToHear => NumberGrid(onNumberTap: _onNumberTap),
              TolurMode.activity => const ActivityRotator(),
            },
            Positioned(
              top: 8,
              right: 8,
              child: TolurModeToggle(
                currentMode: _mode,
                onToggle: () => setState(() => _mode = _mode.next),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
