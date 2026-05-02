// Tölur room mode (Phase 8 D-15).
//
// The Tölur room renders one of two child surfaces:
//   - TolurMode.tapToHear: the 10-NumberTile grid (default)
//   - TolurMode.sequence:  the SequencingActivity (drag-and-drop)
//
// Order is locked. Index 0 = tapToHear, 1 = sequence. The
// [TolurModeToggleExt] `next` getter cycles through them in this order
// (D-15: hold to advance through modes TapToHear → Sequence → TapToHear).
//
// Mirrors Phase 5/6 StafirMode pattern. Pure-Dart enum; lives under
// lib/features/tolur/ (not lib/core/numbers/) because it carries UX
// semantics — the room shape, not the number domain.

enum TolurMode { tapToHear, sequence }

extension TolurModeToggleExt on TolurMode {
  /// Returns the next mode in the cycle. Used by TolurRoom +
  /// TolurModeToggle to advance one step on a successful 3-second hold
  /// (D-15: kid-mode safe via the long hold gate).
  TolurMode get next {
    switch (this) {
      case TolurMode.tapToHear:
        return TolurMode.sequence;
      case TolurMode.sequence:
        return TolurMode.tapToHear;
    }
  }
}
