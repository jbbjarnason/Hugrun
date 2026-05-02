import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marionette_flutter/marionette_flutter.dart';

import 'app/app.dart';
import 'core/db/database_provider.dart';
import 'features/parent_settings/photo_upload/drift_photo_override_source.dart';
import 'features/stafir/matching/matching_providers.dart';

/// Locks the app to landscape orientation and hides system chrome (D-15, D-16).
///
/// Extracted as a top-level function so unit tests can verify the
/// SystemChannels.platform calls without launching `runApp`. See
/// `test/skeleton/main_orientation_test.dart`.
///
/// Decisions:
///   D-15  Tablets in landscape give better grid layout for 32 letters and
///         more comfortable tap zones.
///   D-16  Status bar + navigation bar hidden so the child can't
///         accidentally dismiss the app — parent gate (3 s hold) is the
///         only documented exit affordance.
Future<void> configureSystemChrome() async {
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
}

/// App entry point.
///
/// In debug builds we initialize [MarionetteBinding] so an external Marionette
/// MCP server (`marionette_mcp`, run separately by the AI agent) can attach
/// to this Flutter VM and drive the UI for AI-agent-based smoke testing
/// (Phase 1 Plan 04 / FOUND-07). In release builds we use the default
/// [WidgetsFlutterBinding] so production binaries do not embed the MCP
/// instrumentation surface.
///
/// `MarionetteBinding` must be the only `WidgetsBinding` in the process — see
/// the package README. We do NOT use it from `flutter test` (which initializes
/// `AutomatedTestWidgetsFlutterBinding`) or `integration_test` (which uses
/// `IntegrationTestWidgetsFlutterBinding`); both of those still work because
/// they construct their own bindings before `main()` runs.
Future<void> main() async {
  if (kDebugMode) {
    MarionetteBinding.ensureInitialized();
  } else {
    WidgetsFlutterBinding.ensureInitialized();
  }
  // D-15 / D-16: lock landscape + immersive before runApp so the first frame
  // already respects the orientation. SystemChrome requires a binding, which
  // we ensure above.
  await configureSystemChrome();
  runApp(
    ProviderScope(
      // Phase 10 D-13: override the photo source binding from Phase 5's empty
      // stub to the Drift-backed implementation. The matching round generator
      // sees the new source via `ref.watch` — no code change in the activity.
      overrides: [
        photoOverrideSourceProvider.overrideWith(
          (ref) {
            final source = DriftPhotoOverrideSource(
              ref.watch(appDatabaseProvider),
            );
            ref.onDispose(source.dispose);
            return source;
          },
        ),
      ],
      child: const HugrunApp(),
    ),
  );
}

