// Riverpod providers for Phase 7 letter-tracing activity.
//
// Two providers (chosen for ergonomic test overrides under Riverpod 3.x):
//
//   - traceDataProvider: a function-based @Riverpod that loads all 32
//     glyph JSONs from the asset bundle and returns a fully-populated
//     `Map<IcelandicLetter, TraceGlyph>`. Async (FutureProvider). Tests
//     override with `Future.value(fixtureMap)` and avoid the rootBundle
//     entirely.
//   - tracingCurrentLetterProvider: a Notifier-class @Riverpod that
//     wraps the active letter. Default: random pick from
//     kIcelandicAlphabet. Tests override the underlying initial letter
//     by re-defining the build() return inside a custom Notifier
//     subclass (we expose a small static helper for this).
//
// keepAlive: both providers are app-scoped so the loaded map is
// preserved across activity entries. (Pitfall §4 — pre-warm avoidance.)

import 'dart:math';

import 'package:flutter/services.dart' show rootBundle;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/alphabet/alphabet.dart';
import '../../../core/alphabet/icelandic_letter.dart';
import '../../../core/tracing/glyph_loader.dart';

part 'trace_data_provider.g.dart';

/// Loads all 32 trace glyphs and returns the populated map.
///
/// Production: reads JSONs from `rootBundle`. Tests override this
/// provider with `Future.value(fixtureMap)` to bypass the asset bundle.
///
/// `keepAlive` so the parsed JSONs survive activity entries — Phase 7
/// re-enters the activity each time the toggle cycles back to Trace mode.
@Riverpod(keepAlive: true)
Future<Map<IcelandicLetter, TraceGlyph>> traceData(Ref ref) async {
  final out = <IcelandicLetter, TraceGlyph>{};
  for (final letter in kIcelandicAlphabet) {
    final raw = await rootBundle.loadString(assetPathFor(letter));
    out[letter] = parseGlyphJson(raw);
  }
  return out;
}

/// The currently-traced letter. Default: random pick from
/// kIcelandicAlphabet. Tests override to force a specific letter via
/// `tracingCurrentLetterProvider.overrideWith(() => _ForceLetter(letter))`.
///
/// Auto-advance writes a new value via `.set(nextLetter)` to trigger
/// rebuild of the activity.
@Riverpod(keepAlive: true)
class TracingCurrentLetter extends _$TracingCurrentLetter {
  @override
  IcelandicLetter build() {
    return _pickRandomLetter();
  }

  /// Advances to a new letter (typically a different one — see
  /// pickDifferentLetter). Triggers rebuild of all watchers.
  void set(IcelandicLetter letter) {
    state = letter;
  }
}

IcelandicLetter _pickRandomLetter([Random? rng]) {
  final r = rng ?? Random();
  return kIcelandicAlphabet[r.nextInt(kIcelandicAlphabet.length)];
}

/// Picks a random letter that is NOT [exclude]. If [exclude] is null
/// or the alphabet has only one entry, this is equivalent to picking
/// any random letter. Used by the activity on auto-advance to bias
/// against showing the same letter twice in a row.
IcelandicLetter pickDifferentLetter(IcelandicLetter? exclude, [Random? rng]) {
  final r = rng ?? Random();
  if (exclude == null || kIcelandicAlphabet.length <= 1) {
    return _pickRandomLetter(r);
  }
  IcelandicLetter pick;
  var safety = 32;
  do {
    pick = kIcelandicAlphabet[r.nextInt(kIcelandicAlphabet.length)];
    safety--;
  } while (pick == exclude && safety > 0);
  return pick;
}
