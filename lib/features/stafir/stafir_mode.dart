// Stafir room mode (Phase 5 D-01; Phase 6 D-15 extension).
//
// The Stafir room renders one of three child surfaces:
//   - StafirMode.letters: Phase 4's 32-letter grid (default)
//   - StafirMode.match:   Phase 5's matching activity
//   - StafirMode.cvc:     Phase 6's CVC blending activity
//
// Order is locked. Index 0 = letters, 1 = match, 2 = cvc. The
// [StafirModeToggleExt] `next` getter cycles through them in this order
// (D-15: hold to advance through modes Letters → Match → CVC → Letters).

enum StafirMode { letters, match, cvc }

extension StafirModeToggleExt on StafirMode {
  /// Returns the next mode in the cycle. Used by StafirRoom +
  /// StafirModeToggle to advance one step on a successful 3-second hold
  /// (Phase 6 D-15, D-16 — kid-mode safe via the long hold gate).
  StafirMode get next {
    switch (this) {
      case StafirMode.letters:
        return StafirMode.match;
      case StafirMode.match:
        return StafirMode.cvc;
      case StafirMode.cvc:
        return StafirMode.letters;
    }
  }
}
