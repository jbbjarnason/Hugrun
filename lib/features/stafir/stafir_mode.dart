// Stafir room mode (Phase 5 D-01; Phase 6 D-15 + Phase 7 D-15 extensions).
//
// The Stafir room renders one of four child surfaces:
//   - StafirMode.letters: Phase 4's 32-letter grid (default)
//   - StafirMode.match:   Phase 5's matching activity
//   - StafirMode.cvc:     Phase 6's CVC blending activity
//   - StafirMode.trace:   Phase 7's letter-tracing activity
//
// Order is locked. Index 0 = letters, 1 = match, 2 = cvc, 3 = trace.
// The [StafirModeToggleExt] `next` getter cycles through them in this
// order (Phase 7 D-15: hold to advance through modes
// Letters → Match → CVC → Trace → Letters).

enum StafirMode { letters, match, cvc, trace }

extension StafirModeToggleExt on StafirMode {
  /// Returns the next mode in the cycle. Used by StafirRoom +
  /// StafirModeToggle to advance one step on a successful 3-second hold
  /// (Phase 6 D-15, D-16 / Phase 7 D-15 — kid-mode safe via the long
  /// hold gate).
  StafirMode get next {
    switch (this) {
      case StafirMode.letters:
        return StafirMode.match;
      case StafirMode.match:
        return StafirMode.cvc;
      case StafirMode.cvc:
        return StafirMode.trace;
      case StafirMode.trace:
        return StafirMode.letters;
    }
  }
}
