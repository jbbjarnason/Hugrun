@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

const bannedPackages = <String>[
  'firebase_analytics',
  'firebase_crashlytics',
  'sentry_flutter',
  'mixpanel_flutter',
  'amplitude_flutter',
  'google_mobile_ads',
  'in_app_purchase',
  'app_tracking_transparency',
  'flutter_facebook_audience_network',
];

Future<ProcessResult> runCheck(String fixturePubspecLock) async {
  final tmp = Directory.systemTemp.createTempSync('hugrun-check-no-tracking-');
  try {
    await File(p.join(tmp.path, 'pubspec.lock')).writeAsString(fixturePubspecLock);
    return await Process.run(
      'bash',
      [p.absolute('tools/check-no-tracking.sh')],
      workingDirectory: tmp.path,
    );
  } finally {
    tmp.deleteSync(recursive: true);
  }
}

void main() {
  test('exits 0 on clean pubspec.lock', () async {
    final result = await runCheck(
      'packages:\n  flutter:\n    dependency: "direct main"\n    version: "0.0.0"\n',
    );
    expect(
      result.exitCode,
      0,
      reason: 'stdout=${result.stdout}, stderr=${result.stderr}',
    );
  });

  for (final pkg in bannedPackages) {
    test('exits non-zero when $pkg is present', () async {
      final fixture = '''
packages:
  $pkg:
    dependency: "direct main"
    description:
      name: $pkg
    source: hosted
    version: "1.0.0"
''';
      final result = await runCheck(fixture);
      expect(result.exitCode, isNot(0));
      expect(
        '${result.stdout}${result.stderr}',
        contains(pkg),
      );
    });
  }
}
