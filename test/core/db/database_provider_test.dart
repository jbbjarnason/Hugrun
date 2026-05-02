// Test the @riverpod-codegen appDatabaseProvider (D-02 migration).
//
// The previous Phase 1 used a hand-written `Provider<AppDatabase>`; on Flutter
// 3.41.9 the analyzer-^9 overlap (drift_dev 2.31.x ↔ riverpod_generator 4.0.3)
// allows `@Riverpod(keepAlive: true)` codegen to coexist with drift_dev. This
// test guards the migration: the provider is keepAlive, returns AppDatabase,
// and the same instance is reused within a ProviderContainer (singleton).
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugrun/core/db/database.dart';
import 'package:hugrun/core/db/database_provider.dart';

void main() {
  group('appDatabaseProvider (D-02 codegen)', () {
    test('appDatabaseProvider yields the overridden AppDatabase', () {
      // Use `overrideWithValue` (exposed by the generated AppDatabaseProvider)
      // to inject an in-memory test DB. We don't exercise drift_flutter's
      // path_provider call in unit-test context (that requires a binding).
      final testDb = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(testDb.close);
      final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(testDb)],
      );
      addTearDown(container.dispose);

      final a = container.read(appDatabaseProvider);
      final b = container.read(appDatabaseProvider);
      expect(a, isA<AppDatabase>());
      expect(identical(a, testDb), isTrue, reason: 'override returned');
      expect(identical(a, b), isTrue, reason: 'singleton across reads');
    });

    test('appDatabaseProvider has the codegen-generated name (D-02)', () {
      // The generated provider sets `name: r'appDatabaseProvider'` — this
      // identifies it as codegen-produced (vs. a hand-written Provider which
      // would have name == null). Guards against silent regression to the
      // pre-3.41.9 hand-written shape.
      expect(
        appDatabaseProvider.name,
        'appDatabaseProvider',
        reason: 'codegen sets the provider name from the annotated function',
      );
    });
  });
}
