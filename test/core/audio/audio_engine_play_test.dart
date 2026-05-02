// Plan 04-02 RED tests for AudioEngine.play() and stop().
//
// Validates D-04 (cancel-on-retap, cancel-on-other-tap), D-05 (gapless
// letter→word queue via ConcatenatingAudioSource), and D-22/D-23
// missing-clip graceful fallback.

import 'package:flutter_test/flutter_test.dart';
import 'package:hugrun/core/audio/audio_engine.dart';
import 'package:hugrun/core/manifest/audio_asset.dart';
import 'package:hugrun/core/manifest/utterance_key.dart';

import '_fakes/fake_audio_player.dart';

const _stubManifest = <UtteranceKey, AudioAsset>{
  UtteranceKey.letterA: AudioAsset(
    path: 'assets/audio/letters/names/a.aac',
    approximateDuration: Duration(milliseconds: 100),
  ),
  UtteranceKey.letterEth: AudioAsset(
    path: 'assets/audio/letters/names/eth.aac',
    approximateDuration: Duration(milliseconds: 100),
  ),
  UtteranceKey.letterThorn: AudioAsset(
    path: 'assets/audio/letters/names/thorn.aac',
    approximateDuration: Duration(milliseconds: 100),
  ),
  UtteranceKey.wordHundur: AudioAsset(
    path: 'assets/audio/letters/words/hundur.aac',
    approximateDuration: Duration(milliseconds: 100),
  ),
  UtteranceKey.narrationWelcome: AudioAsset(
    path: 'assets/audio/narration/welcome_hugrun.aac',
    approximateDuration: Duration(milliseconds: 100),
  ),
};

({AudioEngine engine, List<FakeAudioPlayer> fakes}) makeEngine({
  Map<UtteranceKey, AudioAsset>? manifestOverride,
  Map<UtteranceKey, UtteranceKey>? pairingOverride,
}) {
  final fakes = <FakeAudioPlayer>[];
  final engine = AudioEngine(
    playerFactory: () {
      final p = FakeAudioPlayer();
      fakes.add(p);
      return p;
    },
    manifestOverride: manifestOverride ?? _stubManifest,
    pairingOverride: pairingOverride ?? const <UtteranceKey, UtteranceKey>{},
  );
  return (engine: engine, fakes: fakes);
}

void main() {
  group('AudioEngine.play (D-04, D-05, STAFIR-02..05)', () {
    test('play(letterA) sets the letter-name asset on a pool player', () async {
      final t = makeEngine();
      await t.engine.warmUp();
      final priorPlayCalls = t.fakes
          .map((p) => p.calls.where((c) => c.method == 'play').length)
          .reduce((a, b) => a + b);

      await t.engine.play(UtteranceKey.letterA);
      // At least one player has a setAsset OR setAudioSource call AFTER warmUp.
      final dispatchedCalls = t.fakes
          .expand((p) => p.calls)
          .where(
            (c) => c.method == 'setAsset' || c.method == 'setAudioSource',
          );
      expect(
        dispatchedCalls.where((c) {
          if (c.method == 'setAsset') {
            return (c.args.first as String?)?.contains('a.aac') ?? false;
          }
          return false;
        }),
        isNotEmpty,
      );
      // play() was called at least once more after dispatch (warmUp primed
      // player 0 which also called play once).
      final playCallTotal = t.fakes
          .map((p) => p.calls.where((c) => c.method == 'play').length)
          .reduce((a, b) => a + b);
      expect(playCallTotal, greaterThan(priorPlayCalls));
    });

    test(
      'play(letterA) does NOT instantiate new players — pool size stays 4',
      () async {
        final t = makeEngine();
        await t.engine.warmUp();
        final initialFakeCount = t.fakes.length;
        expect(initialFakeCount, AudioEngine.poolSize);

        await t.engine.play(UtteranceKey.letterA);
        await t.engine.play(UtteranceKey.letterEth);
        await t.engine.play(UtteranceKey.letterThorn);

        expect(t.fakes.length, initialFakeCount);
      },
    );

    test(
      'play(letterA) followed by play(letterA) cancels and re-plays',
      () async {
        final t = makeEngine();
        await t.engine.warmUp();

        await t.engine.play(UtteranceKey.letterA);
        // Find which fake got the dispatched call.
        final firstDispatcher = t.fakes.firstWhere(
          (p) => p.calls.any(
            (c) =>
                (c.method == 'setAsset' || c.method == 'setAudioSource') &&
                p.calls.indexOf(c) > 0,
          ),
          orElse: () => t.fakes[0],
        );
        final stopsBefore = firstDispatcher.calls
            .where((c) => c.method == 'stop')
            .length;

        await t.engine.play(UtteranceKey.letterA);

        // After re-tap, we expect the previously-active player to have
        // received a stop() call (cancel-on-retap, D-04, STAFIR-04).
        final stopsAfter = t.fakes
            .map((p) => p.calls.where((c) => c.method == 'stop').length)
            .reduce((a, b) => a + b);
        expect(
          stopsAfter,
          greaterThan(stopsBefore),
          reason: 'cancel-on-retap fires stop() on the active player',
        );
      },
    );

    test(
      'play(letterA) followed by play(letterEth) cancels first and starts second',
      () async {
        final t = makeEngine();
        await t.engine.warmUp();

        await t.engine.play(UtteranceKey.letterA);
        final stopsBefore = t.fakes
            .map((p) => p.calls.where((c) => c.method == 'stop').length)
            .reduce((a, b) => a + b);
        await t.engine.play(UtteranceKey.letterEth);
        final stopsAfter = t.fakes
            .map((p) => p.calls.where((c) => c.method == 'stop').length)
            .reduce((a, b) => a + b);

        expect(stopsAfter, greaterThan(stopsBefore));

        // Eth was dispatched on some player (different slot likely; round-robin).
        final ethDispatched = t.fakes.any(
          (p) => p.calls.any(
            (c) =>
                c.method == 'setAsset' &&
                ((c.args.first as String?)?.contains('eth') ?? false),
          ),
        );
        expect(ethDispatched, isTrue);
      },
    );

    test('play() with missing manifest entry logs warning and does NOT throw', () async {
      final fakes = <FakeAudioPlayer>[];
      // Manifest that intentionally lacks letterA.
      const sparseManifest = <UtteranceKey, AudioAsset>{
        UtteranceKey.narrationWelcome: AudioAsset(
          path: 'assets/audio/narration/welcome_hugrun.aac',
          approximateDuration: Duration(milliseconds: 100),
        ),
      };
      final engine = AudioEngine(
        playerFactory: () {
          final p = FakeAudioPlayer();
          fakes.add(p);
          return p;
        },
        manifestOverride: sparseManifest,
      );
      await engine.warmUp();
      // Should not throw, returns silently.
      expect(
        () => engine.play(UtteranceKey.letterA),
        returnsNormally,
      );
    });

    test('play() returns a Future that completes (does not deadlock)', () async {
      final t = makeEngine();
      await t.engine.warmUp();
      // Bound the await so a hang in play() shows up as a test timeout.
      await t.engine
          .play(UtteranceKey.letterA)
          .timeout(const Duration(milliseconds: 500));
    });

    test('play() with a paired word queues both clips via setAudioSources', () async {
      final t = makeEngine(
        pairingOverride: const <UtteranceKey, UtteranceKey>{
          UtteranceKey.letterA: UtteranceKey.wordHundur,
        },
      );
      await t.engine.warmUp();
      await t.engine.play(UtteranceKey.letterA);

      // At least one fake should have received a setAudioSources call (the
      // playlist path), NOT a setAsset (single-clip path).
      final hasSetSources = t.fakes.any(
        (p) => p.calls.any((c) => c.method == 'setAudioSources'),
      );
      expect(
        hasSetSources,
        isTrue,
        reason:
            'paired letter→word path queues via setAudioSources playlist for gapless playback',
      );
    });
  });

  group('AudioEngine.stop', () {
    test('stop() does not throw when nothing is playing', () async {
      final t = makeEngine();
      await t.engine.warmUp();
      expect(() => t.engine.stop(), returnsNormally);
    });

    test('stop() after play() halts the active player', () async {
      final t = makeEngine();
      await t.engine.warmUp();
      await t.engine.play(UtteranceKey.letterA);
      final stopsBefore = t.fakes
          .map((p) => p.calls.where((c) => c.method == 'stop').length)
          .reduce((a, b) => a + b);
      await t.engine.stop();
      final stopsAfter = t.fakes
          .map((p) => p.calls.where((c) => c.method == 'stop').length)
          .reduce((a, b) => a + b);
      expect(stopsAfter, greaterThan(stopsBefore));
    });
  });
}
