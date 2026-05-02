import 'package:flutter/material.dart';

import 'parent_gate_controller.dart';

/// 3-second hold-to-open parent gate (D-22). Wraps any [child] widget;
/// holding it for [holdDuration] (default 3 s) calls [onCompleted].
/// During hold, an animated ring fills clockwise around the press point.
/// No haptic feedback in v1 per D-23.
class ParentGate extends StatefulWidget {
  const ParentGate({
    super.key,
    required this.child,
    required this.onCompleted,
    this.onTap,
    this.holdDuration = const Duration(seconds: 3),
    this.ringDiameter = 64,
  });

  final Widget child;
  final VoidCallback onCompleted;
  final VoidCallback? onTap;
  final Duration holdDuration;
  final double ringDiameter;

  @override
  State<ParentGate> createState() => _ParentGateState();
}

class _ParentGateState extends State<ParentGate>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;
  late final ParentGateController _controller;
  bool _isHolding = false;

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(
      vsync: this,
      duration: widget.holdDuration,
    );
    _controller = ParentGateController(
      duration: widget.holdDuration,
      onCompleted: () {
        if (mounted) widget.onCompleted();
      },
    );
  }

  @override
  void dispose() {
    _animation.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _start() {
    setState(() => _isHolding = true);
    _controller.onPressStart();
    _animation.forward(from: 0);
  }

  void _end() {
    if (!_isHolding) return;
    setState(() => _isHolding = false);
    _controller.onPressEnd();
    _animation.stop();
    _animation.value = 0;
  }

  @override
  Widget build(BuildContext context) {
    // Use Listener (raw pointer events) instead of GestureDetector — the
    // built-in long-press recognizers fire after ~500ms and steal the gesture
    // arena, breaking our "begin timer immediately on touch" semantics.
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => _start(),
      onPointerUp: (_) => _end(),
      onPointerCancel: (_) => _end(),
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          GestureDetector(onTap: widget.onTap, child: widget.child),
          if (_isHolding)
            IgnorePointer(
              child: SizedBox(
                key: const Key('parent-gate-ring'),
                width: widget.ringDiameter,
                height: widget.ringDiameter,
                child: AnimatedBuilder(
                  animation: _animation,
                  builder: (context, _) => CircularProgressIndicator(
                    value: _animation.value,
                    strokeWidth: 4,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
