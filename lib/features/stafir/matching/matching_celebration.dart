// Celebration overlay for the Letter-to-Word Matching activity (Phase 5
// Plan 05-02).
//
// Decisions exercised:
//   D-08  Tasteful celebration: soft scale-up + checkmark fade-in. NO stars,
//         NO trophies, NO score numbers. Single Icon, single color.
//   D-09  Total reserved time = 1.5s before auto-advance.
//   D-10  No score, no streak, no count, no timer ever rendered.
//
// Layering: this widget owns ONLY the visual cue. The MatchingActivity
// (Plan 05-02 Task 3) drives `visible` and is responsible for the
// auto-advance Timer using [duration].

import 'package:flutter/material.dart';

/// Overlay shown on a correct tap. Caller controls [visible]; the widget
/// drives an internal AnimationController that scales + fades a single
/// checkmark icon.
class MatchingCelebration extends StatefulWidget {
  const MatchingCelebration({super.key, required this.visible});

  /// Whether the overlay is active. False renders nothing visible. True
  /// runs the forward animation from 0 to 1.
  final bool visible;

  /// Total reserved animation duration (D-09). The MatchingActivity reads
  /// this constant to schedule its auto-advance Timer.
  static const Duration duration = Duration(milliseconds: 1500);

  @override
  State<MatchingCelebration> createState() => _MatchingCelebrationState();
}

class _MatchingCelebrationState extends State<MatchingCelebration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      // Forward animation runs ~600ms (the bulk of [duration] is for
      // dwell time so the child can register the cue before auto-advance).
      duration: const Duration(milliseconds: 600),
    );
    _scale = Tween<double>(
      begin: 0.6,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _opacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    if (widget.visible) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(MatchingCelebration oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible && !oldWidget.visible) {
      _controller.forward(from: 0);
    } else if (!widget.visible && oldWidget.visible) {
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible) return const SizedBox.shrink();
    return Positioned.fill(
      child: IgnorePointer(
        key: const Key('matching-celebration-active'),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => Center(
            child: Opacity(
              opacity: _opacity.value,
              child: Transform.scale(
                scale: _scale.value,
                // Single Icon, soft green, ~160 logical px. No
                // additional decoration, no halo, no stars.
                child: const Icon(
                  Icons.check_circle_rounded,
                  size: 160,
                  color: Color(0xFF66BB6A),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
