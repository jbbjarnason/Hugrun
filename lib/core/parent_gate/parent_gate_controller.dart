import 'dart:async';

/// Pure-Dart state machine for the parent gate. No Flutter dependency
/// (D-08 domain purity for testable logic). The widget wraps this with
/// AnimationController for the visual ring; this controller owns the
/// timing semantics: idle → holding (timer running) → completed | aborted.
class ParentGateController {
  ParentGateController({required this.duration, required this.onCompleted});

  final Duration duration;
  final void Function() onCompleted;

  Timer? _timer;
  bool _isHolding = false;
  bool _isCompleted = false;

  bool get isHolding => _isHolding;
  bool get isCompleted => _isCompleted;

  /// Begin the hold. Cancels any previous timer (restart, not resume).
  void onPressStart() {
    _timer?.cancel();
    _isHolding = true;
    _isCompleted = false;
    _timer = Timer(duration, () {
      _isHolding = false;
      _isCompleted = true;
      onCompleted();
    });
  }

  /// Release before duration. Aborts the timer; gate does not fire.
  /// Released after completion (rare race) is harmless.
  void onPressEnd() {
    if (_isCompleted) return;
    _timer?.cancel();
    _isHolding = false;
  }

  void dispose() {
    _timer?.cancel();
  }
}
