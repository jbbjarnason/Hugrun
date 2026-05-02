// Stafir room mode (Phase 5 D-01).
//
// The Stafir room renders one of two child surfaces:
//   - StafirMode.letters: Phase 4's 32-letter grid (default)
//   - StafirMode.match:   Phase 5's matching activity
//
// Order is locked. Index 0 = letters, 1 = match. The [StafirModeToggleExt]
// `next` getter relies on this order to swap unambiguously between the two.

enum StafirMode { letters, match }

extension StafirModeToggleExt on StafirMode {
  /// Returns the opposite mode. Used by StafirRoom + StafirModeToggle to
  /// toggle on a successful 3-second hold.
  StafirMode get next =>
      this == StafirMode.letters ? StafirMode.match : StafirMode.letters;
}
