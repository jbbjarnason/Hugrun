import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/audio/audio_engine_provider.dart';
import '../parent_settings/child_name_provider.dart';
import 'welcome_narration_keys.dart';

part 'welcome_narration_controller.g.dart';

/// App-scoped (D-19, D-20) — survives room navigation. The once-per-
/// session flag lives on this object; HomePage's initState calls
/// [maybeFireOnce] on every mount, but the second call is a no-op.
///
/// Per D-21: name changes mid-session do NOT re-trigger the welcome.
/// The controller reads childNameProvider via `.future` (single-shot
/// snapshot), NOT `.watch`.
@Riverpod(keepAlive: true)
class WelcomeNarrationController extends _$WelcomeNarrationController {
  bool _fired = false;

  @override
  WelcomeNarrationController build() => this;

  /// Fires the welcome narration exactly once per app session.
  /// Subsequent calls are no-ops. Exception-safe — never propagates.
  Future<void> maybeFireOnce() async {
    if (_fired) return;
    // Claim the slot BEFORE any await so concurrent calls deduplicate.
    _fired = true;

    try {
      final name = await ref.read(childNameProvider.future);
      final key = selectWelcomeNarrationKey(name);
      if (key == null) {
        debugPrint(
          '[WelcomeNarration] no welcome variant available for name=$name; skipping.',
        );
        return;
      }
      // Fire-and-forget through AudioEngine. Plan 04-02's play() handles
      // missing-clip fallback (Phase 2 stub manifest may not have the
      // generic variant yet). Wrap in catch so the future doesn't surface
      // unhandled errors at the zone level.
      unawaited(
        ref.read(audioEngineProvider).play(key).catchError((Object e) {
          debugPrint('[WelcomeNarration] play() error swallowed: $e');
        }),
      );
    } catch (e) {
      debugPrint('[WelcomeNarration] error: $e');
      // Do NOT propagate. HomePage build must not crash because of audio.
    }
  }
}
