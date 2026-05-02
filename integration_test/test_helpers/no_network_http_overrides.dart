import 'dart:io';

/// Throws on any outbound HTTP request. Install in `setUp()` of any
/// integration test that should validate the no-network constraint
/// (FOUND-10). Per CONTEXT D-18 — covers FOUND-10 verification.
class NoNetworkHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    throw StateError(
      'Network access is forbidden during play sessions (D-18 / FOUND-10). '
      'A test or runtime path attempted to create an HttpClient.',
    );
  }
}
