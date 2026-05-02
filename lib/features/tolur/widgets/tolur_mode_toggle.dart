// Tölur mode toggle button. Phase 8 Plan 08-04 D-15.
//
// Mirror of Phase 5/6's StafirModeToggle: a small icon-only widget that
// requires a 3-second hold to call onToggle. Reuses Phase 1's
// [ParentGateController] state machine for the hold-timing semantics.
//
// Reuse rationale (matches StafirModeToggle):
//   - Small footprint (≤64×64 logical px) — the parent gate widget wraps
//     a child and is much larger.
//   - The (idle → holding → completed) state machine is the part worth
//     reusing; the chrome differs.
//
// No haptic feedback (Phase 1 D-23 forbade haptics on the parent gate;
// keeping the same posture here for consistency).

import 'package:flutter/material.dart';

import '../../../core/parent_gate/parent_gate_controller.dart';
import '../tolur_mode.dart';

class TolurModeToggle extends StatefulWidget {
  const TolurModeToggle({
    super.key,
    required this.currentMode,
    required this.onToggle,
    this.holdDuration = const Duration(seconds: 3),
  });

  /// Drives the icon (image_outlined for tapToHear, format_list_numbered
  /// for sequence — see _StateBuild for the mapping).
  final TolurMode currentMode;

  /// Invoked once after a successful 3-second hold. The parent owns the
  /// mode state; this widget only signals when to swap.
  final VoidCallback onToggle;

  /// How long the user must hold to fire [onToggle]. Defaults to 3 seconds
  /// (D-15: long enough that an accidental kid-tap doesn't trigger).
  final Duration holdDuration;

  @override
  State<TolurModeToggle> createState() => _TolurModeToggleState();
}

class _TolurModeToggleState extends State<TolurModeToggle>
    with TickerProviderStateMixin {
  late ParentGateController _controller;
  late AnimationController _ringAnim;
  bool _holding = false;

  @override
  void initState() {
    super.initState();
    _ringAnim = AnimationController(
      vsync: this,
      duration: widget.holdDuration,
    );
    _controller = ParentGateController(
      duration: widget.holdDuration,
      onCompleted: () {
        if (!mounted) return;
        setState(() => _holding = false);
        _ringAnim.stop();
        _ringAnim.value = 0;
        widget.onToggle();
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _ringAnim.dispose();
    super.dispose();
  }

  void _start() {
    setState(() => _holding = true);
    _controller.onPressStart();
    _ringAnim.forward(from: 0);
  }

  void _endHold() {
    if (!_holding) return;
    setState(() => _holding = false);
    _controller.onPressEnd();
    _ringAnim.stop();
    _ringAnim.value = 0;
  }

  @override
  Widget build(BuildContext context) {
    // D-15: 2 distinct icons.
    //  tapToHear → image_outlined        (the digit grid)
    //  activity  → category_outlined     (mixed-activity rotation)
    final IconData iconData;
    switch (widget.currentMode) {
      case TolurMode.tapToHear:
        iconData = Icons.image_outlined;
      case TolurMode.activity:
        iconData = Icons.category_outlined;
    }
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => _start(),
      onPointerUp: (_) => _endHold(),
      onPointerCancel: (_) => _endHold(),
      child: SizedBox(
        width: 48,
        height: 48,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            Icon(iconData, size: 28, color: const Color(0xFF555555)),
            if (_holding)
              Positioned.fill(
                child: IgnorePointer(
                  key: const Key('tolur-mode-toggle-hold-ring'),
                  child: AnimatedBuilder(
                    animation: _ringAnim,
                    builder: (context, _) => CircularProgressIndicator(
                      value: _ringAnim.value,
                      strokeWidth: 2,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
