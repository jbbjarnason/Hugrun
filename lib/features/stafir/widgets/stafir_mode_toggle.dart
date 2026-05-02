// Stafir mode toggle button (Phase 5 D-01).
//
// A tiny icon-only widget that requires a 3-second hold to call onToggle.
// Reuses Phase 1's [ParentGateController] state machine for the hold-timing
// semantics — same gesture pattern as the parent gate, just without the
// ring chrome surrounding the child widget.
//
// Why reuse the controller, not the widget:
//   - We want a small footprint (≤ 48×48 logical px) — the parent gate
//     wraps a child and is much larger.
//   - The state machine (idle → holding → completed) is the part worth
//     reusing; the widget chrome differs.
//
// No haptic feedback (Phase 1 D-23 forbade haptics on the parent gate;
// keeping the same posture here for consistency).

import 'package:flutter/material.dart';

import '../../../core/parent_gate/parent_gate_controller.dart';
import '../stafir_mode.dart';

class StafirModeToggle extends StatefulWidget {
  const StafirModeToggle({
    super.key,
    required this.currentMode,
    required this.onToggle,
    this.holdDuration = const Duration(seconds: 3),
  });

  /// Drives the icon (image_outlined in letters mode, grid_view_outlined
  /// in match mode).
  final StafirMode currentMode;

  /// Invoked once after a successful 3-second hold. The parent owns the
  /// mode state; this widget only signals when to swap.
  final VoidCallback onToggle;

  /// How long the user must hold to fire [onToggle]. Defaults to 3 seconds
  /// (D-01: long enough that an accidental kid-tap doesn't trigger).
  final Duration holdDuration;

  @override
  State<StafirModeToggle> createState() => _StafirModeToggleState();
}

class _StafirModeToggleState extends State<StafirModeToggle>
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
    // Phase 12 UI-02 — ONE consistent icon across every mode.
    // The toggle is a "tap-and-hold to cycle" affordance, NOT a
    // "current mode badge". Icons.swap_horiz reads as "swap to
    // the next thing" without requiring literacy.
    //
    // Previous (Phase 6/7) per-mode icon mapping is dropped; the
    // hold-ring (which fills during the 3s hold gesture) is the
    // sole visual hint that something happens on hold. The
    // `currentMode` field is kept on the widget for API
    // compatibility (callers pass it) but no longer drives the icon.
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
            const Icon(
              Icons.swap_horiz,
              size: 28,
              color: Color(0xFF555555),
            ),
            if (_holding)
              Positioned.fill(
                child: IgnorePointer(
                  key: const Key('stafir-mode-toggle-hold-ring'),
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
