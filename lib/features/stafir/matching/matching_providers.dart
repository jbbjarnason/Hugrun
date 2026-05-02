// Riverpod providers for the Letter-to-Word Matching activity (Phase 5).
//
// Both providers are keepAlive: the matching activity may be navigated to
// and from (Plan 05-03 mode toggle) and we want the round generator's
// state (and the photo source) to persist for the session, not reset on
// every navigation.
//
// Phase 10 (PHOTO-*) will override `photoOverrideSourceProvider` at the
// app's `ProviderScope` to inject a Drift-backed implementation; the
// `roundGeneratorProvider` will pick up the new source via `ref.watch`
// without any code change here.

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/matching/photo_override_source.dart';
import '../../../core/matching/round_generator.dart';

part 'matching_providers.g.dart';

/// Phase 5 default photo source — empty (D-13). Phase 10 swaps the binding
/// to a Drift-backed implementation; the round generator sees the new
/// source via [ref.watch].
@Riverpod(keepAlive: true)
PhotoOverrideSource photoOverrideSource(Ref ref) =>
    const EmptyPhotoOverrideSource();

/// Round generator wired to the photo source. keepAlive so the activity
/// keeps its (un-seeded) Random sequence as the user navigates between
/// Letters and Match modes.
@Riverpod(keepAlive: true)
RoundGenerator roundGenerator(Ref ref) =>
    RoundGenerator(photoSource: ref.watch(photoOverrideSourceProvider));
