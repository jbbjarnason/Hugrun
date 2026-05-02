// Tölur room mode (Phase 9 D-15 — simplified from Phase 8 2-mode shape).
//
// CONTEXT D-15 (Phase 9): "simplify to a 'shuffle mode' approach — Tölur
// has just 2 modes (TapToHear / Activity), and 'Activity' rotates through
// Sequence → Correspondence → Subitizing → Addition randomly between
// rounds. Pick this approach — keeps the toggle simple for the kid;
// activity variety happens automatically."
//
// The Tölur room renders one of two child surfaces:
//   - TolurMode.tapToHear: the 10-NumberTile grid (default)
//   - TolurMode.activity:  the ActivityRotator — randomly picks one of
//                          {Sequencing, Correspondence, Subitizing, Addition}
//                          per round.
//
// Order is locked. Index 0 = tapToHear, 1 = activity. The
// [TolurModeToggleExt] `next` getter cycles through them in this order
// (D-15: hold to advance through modes TapToHear → Activity → TapToHear).
//
// Mirrors Phase 5/6 StafirMode pattern. Pure-Dart enum; lives under
// lib/features/tolur/ (not lib/core/numbers/) because it carries UX
// semantics — the room shape, not the number domain.

enum TolurMode { tapToHear, activity }

extension TolurModeToggleExt on TolurMode {
  /// Returns the next mode in the cycle. Used by TolurRoom +
  /// TolurModeToggle to advance one step on a successful 3-second hold
  /// (D-15: kid-mode safe via the long hold gate).
  TolurMode get next {
    switch (this) {
      case TolurMode.tapToHear:
        return TolurMode.activity;
      case TolurMode.activity:
        return TolurMode.tapToHear;
    }
  }
}
