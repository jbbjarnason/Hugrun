// Plan 04-01 RED tests for the orientation lock + immersive mode wiring
// in lib/main.dart (D-15, D-16).
//
// We don't pump main(); instead, we extract `configureSystemChrome()` and
// verify it issues the expected SystemChannels.platform calls. The pattern
// follows Flutter's own testing guidance for SystemChrome: replace the
// platform channel handler with a recorder.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugrun/main.dart' as app_main;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> recordedCalls;

  setUp(() {
    recordedCalls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          recordedCalls.add(call);
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  test(
    'configureSystemChrome calls setPreferredOrientations with [landscapeLeft, landscapeRight] only',
    () async {
      await app_main.configureSystemChrome();
      final orientationCalls = recordedCalls
          .where((c) => c.method == 'SystemChrome.setPreferredOrientations')
          .toList();
      expect(orientationCalls.length, 1);
      final args = orientationCalls.first.arguments as List<dynamic>;
      expect(
        args,
        containsAll(<String>[
          'DeviceOrientation.landscapeLeft',
          'DeviceOrientation.landscapeRight',
        ]),
      );
      expect(args.length, 2, reason: 'no portrait orientations allowed');
    },
  );

  test(
    'configureSystemChrome calls setEnabledSystemUIMode with SystemUiMode.immersive',
    () async {
      await app_main.configureSystemChrome();
      final modeCalls = recordedCalls
          .where((c) => c.method == 'SystemChrome.setEnabledSystemUIMode')
          .toList();
      expect(modeCalls.length, 1);
      final args = modeCalls.first.arguments as Map<dynamic, dynamic>;
      expect(args['mode'], 'SystemUiMode.immersive');
    },
  );
}
