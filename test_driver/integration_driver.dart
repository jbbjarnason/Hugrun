import 'package:integration_test/integration_test_driver.dart';

/// Test driver for `flutter drive` orchestration of integration_test/.
///
/// Used by:
///
/// ```sh
/// flutter drive \
///   --driver=test_driver/integration_driver.dart \
///   --target=integration_test/marionette_smoke_test.dart \
///   -d DEVICE_ID
/// ```
///
/// Phase 1 Plan 04: this driver runs a scripted smoke that exercises the
/// same widget paths a Marionette MCP agent would drive interactively.
/// Keeping a scripted variant alongside the MCP harness gives us a green
/// CI signal independent of an AI agent being available — see
/// marionette/README.md for the rationale.
Future<void> main() => integrationDriver();
