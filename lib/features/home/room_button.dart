import 'package:flutter/material.dart';

/// Generic room entry button. Phase 1 — text label only. Phase 4 may
/// gain illustrations + per-room theming. Min 88×88 logical-px tap target
/// — proxy for the ≥2 cm physical target on Hugrún's tablet (verified
/// end-to-end by Plan 04 Marionette E2E using device DPI).
class RoomButton extends StatelessWidget {
  const RoomButton({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minWidth: 200, minHeight: 200),
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline,
            width: 2,
          ),
        ),
        child: Center(
          child: Text(label, style: Theme.of(context).textTheme.headlineLarge),
        ),
      ),
    );
  }
}
