import 'package:flutter/material.dart';

/// Generic room entry button.
///
/// Phase 1 — text label only.
/// Phase 12 UI-03 — optional `glyph` widget rendered prominently above the
/// text label so a pre-reading 5-year-old can recognize the room visually.
/// HomePage passes a styled alphabet motif for Stafir and a numeral motif
/// for Tölur.
///
/// Min 88×88 logical-px tap target — proxy for the ≥2 cm physical target
/// on Hugrún's tablet (verified end-to-end by Plan 04 Marionette E2E
/// using device DPI).
class RoomButton extends StatelessWidget {
  const RoomButton({
    super.key,
    required this.label,
    required this.onTap,
    this.glyph,
  });

  final String label;
  final VoidCallback onTap;

  /// Optional large glyph rendered above the [label]. Phase 12 UI-03 —
  /// the glyph is the dominant visual; the [label] becomes a small
  /// caption underneath. Stays nullable so existing callers (or
  /// non-room contexts) keep working unchanged.
  final Widget? glyph;

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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (glyph != null) ...<Widget>[
                glyph!,
                const SizedBox(height: 12),
              ],
              // Phase 12 UI-03 — when a glyph is present, the text label
              // becomes a small caption (titleMedium). The glyph is the
              // dominant affordance for a pre-reader. When no glyph is
              // provided we fall back to the original headline-large
              // posture for backward compatibility.
              Text(
                label,
                style: glyph == null
                    ? Theme.of(context).textTheme.headlineLarge
                    : Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
