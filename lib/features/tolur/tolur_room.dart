// Tölur (Numbers) room. Phase 8 Plan 08-02 (Workstream B).
//
// Phase 8 Workstream B (this commit) ships the tap-to-hear surface only:
// 10 NumberTiles for digits 1..10, tapping plays the masculine variant
// for 1..4 (NUM-03 abstract counting) and the invariant key for 5..10.
//
// Workstream C/D extend the room with a sequencing activity and a
// TolurMode toggle (TapToHear / Sequence). The toggle reuses the Phase 5
// mode-toggle pattern (3-second hold via ParentGateController) — added
// in a later commit so the diff stays focused on the tap-to-hear loop.
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
import 'widgets/number_grid.dart';

class TolurRoom extends ConsumerStatefulWidget {
  const TolurRoom({super.key});

  @override
  ConsumerState<TolurRoom> createState() => TolurRoomState();
}

/// Public so widget tests can drive helpers without simulating gestures
/// (mirrors StafirRoomState pattern).
class TolurRoomState extends ConsumerState<TolurRoom> {
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
        child: NumberGrid(onNumberTap: _onNumberTap),
      ),
    );
  }
}
