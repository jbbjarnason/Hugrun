// Riverpod providers for the CVC blending activity (Phase 6 Plan 06-02).
//
// Two providers:
//   - cvcWordPoolProvider: the static const list of 8 starter words. Override
//     in tests if a smaller pool is desired.
//   - cvcCurrentWordProvider: the round's currently-displayed CvcWord. Default
//     implementation picks at random from the pool; tests override to force
//     a deterministic word.
//
// keepAlive: the activity may be navigated to + from (Plan 05-03 mode toggle
// pattern). Keeping the providers alive lets a pseudo-random round sequence
// continue across navigations.

import 'dart:math';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/cvc/cvc_word.dart';
import '../../../core/cvc/cvc_words.dart';

part 'cvc_providers.g.dart';

/// The pool of CVC starter words. Phase 6 ships kCvcWords (8 words);
/// Phase 7+ may extend or override.
@Riverpod(keepAlive: true)
List<CvcWord> cvcWordPool(Ref ref) => kCvcWords;

/// The round's currently-displayed CVC word. Default: pick at random
/// from cvcWordPoolProvider. Tests override this provider to force a
/// specific word so assertions can check phoneme keys deterministically.
@Riverpod(keepAlive: true)
CvcWord cvcCurrentWord(Ref ref) {
  final pool = ref.watch(cvcWordPoolProvider);
  if (pool.isEmpty) {
    throw StateError(
      'cvcCurrentWordProvider: pool is empty — cannot pick a word',
    );
  }
  return pool[Random().nextInt(pool.length)];
}
