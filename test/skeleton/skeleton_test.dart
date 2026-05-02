import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Project skeleton (CONTEXT D-07)', () {
    const requiredDirs = <String>[
      'lib/app',
      'lib/core/audio',
      'lib/core/db',
      'lib/core/parent_gate',
      'lib/core/manifest',
      'lib/features/home',
      'lib/features/stafir',
      'lib/features/tolur',
      'lib/features/parent_settings',
      'lib/mechanics',
      'lib/gen',
      'test',
      'assets',
    ];
    for (final d in requiredDirs) {
      test('$d exists', () {
        expect(
          Directory(d).existsSync(),
          isTrue,
          reason: 'D-07 requires $d to exist (with .gitkeep if empty)',
        );
      });
    }
  });

  group('pubspec dependency family pins (D-01, D-06)', () {
    late String lock;
    setUpAll(() => lock = File('pubspec.lock').readAsStringSync());

    test('flutter_riverpod is present', () {
      expect(lock.contains('flutter_riverpod:'), isTrue);
    });

    test('drift_flutter present, sqlite3_flutter_libs is NOT a direct dep', () {
      expect(lock.contains('drift_flutter:'), isTrue);
      // sqlite3_flutter_libs may appear transitively but must not be marked
      // dependency: "direct main" — D-06 forbids direct dep.
      final transitive = RegExp(
        r'sqlite3_flutter_libs:\s*\n\s*dependency:\s*"direct main"',
      ).hasMatch(lock);
      expect(
        transitive,
        isFalse,
        reason: 'D-06: sqlite3_flutter_libs must not be a direct dependency',
      );
    });

    test('just_audio is 0.10.x family', () {
      final m = RegExp(
        r'just_audio:\s*\n\s*dependency:.*?\n\s*description:.*?\n\s*source:.*?\n\s*version:\s*"0\.(\d+)\.',
        dotAll: true,
      ).firstMatch(lock);
      expect(m, isNotNull);
      expect(int.parse(m!.group(1)!), greaterThanOrEqualTo(10));
    });

    test('drift is 2.28.x or newer', () {
      // Drift 2.28.1 is the Phase 1 floor (forced by Dart 3.10.7 / build_runner
      // 2.4.x compatibility). Phase 4 revisits and bumps to 2.32+.
      final m = RegExp(
        r'\s+drift:\s*\n\s*dependency:.*?\n\s*description:.*?\n\s*source:.*?\n\s*version:\s*"(\d+)\.(\d+)\.',
        dotAll: true,
      ).firstMatch(lock);
      expect(m, isNotNull);
      expect(int.parse(m!.group(1)!), greaterThanOrEqualTo(2));
      expect(int.parse(m.group(2)!), greaterThanOrEqualTo(28));
    });
  });
}
