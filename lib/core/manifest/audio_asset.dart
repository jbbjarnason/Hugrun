// Pure-Dart value class for a single audio manifest entry. Phase 1 D-08 +
// Phase 2 D-13 require lib/core/manifest/ to stay Flutter-free. We avoid the
// `package:meta/meta.dart` `@immutable` hint to keep the dependency surface
// minimal; the const constructor + final fields + manual `operator ==` /
// `hashCode` deliver the same immutability guarantees.

/// One audio asset referenced by the manifest.
///
/// - [path]: project-relative path under `assets/audio/` (e.g.
///   `assets/audio/letters/names/a.aac`). Lowercase ASCII per D-06; matches
///   the form Flutter uses internally for asset lookup via
///   `rootBundle.load(...)`.
/// - [approximateDuration]: best-effort clip length. Phase 2 placeholder
///   clips report 100 ms per D-09; Phase 3's Python pipeline measures the
///   actual length and writes the precise value.
class AudioAsset {
  const AudioAsset({required this.path, required this.approximateDuration});

  final String path;
  final Duration approximateDuration;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AudioAsset &&
          runtimeType == other.runtimeType &&
          path == other.path &&
          approximateDuration == other.approximateDuration;

  @override
  int get hashCode => Object.hash(path, approximateDuration);

  @override
  String toString() =>
      'AudioAsset(path: $path, approximateDuration: $approximateDuration)';
}
