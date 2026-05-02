import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marionette_flutter/marionette_flutter.dart';

import 'app/app.dart';

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
void main() {
  if (kDebugMode) {
    MarionetteBinding.ensureInitialized();
  } else {
    WidgetsFlutterBinding.ensureInitialized();
  }
  runApp(const ProviderScope(child: HugrunApp()));
}
