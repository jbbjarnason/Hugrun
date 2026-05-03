import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../example_word_resolver.dart';

/// Controller for the [ExampleWordOverlay]. Stafir's tap handler calls
/// `controller.show(wordSlug)` to fade in the example-word visual.
class ExampleWordOverlayController extends ChangeNotifier {
  String? _wordSlug;
  String? get wordSlug => _wordSlug;

  void show(String wordSlug) {
    _wordSlug = wordSlug;
    notifyListeners();
  }

  void hide() {
    _wordSlug = null;
    notifyListeners();
  }
}

/// Plan 04-04 D-12. Fades an image (or placeholder text-on-color tile)
/// in/out for ~3 seconds while the example-word audio plays.
///
/// If the image asset doesn't exist (Phase 2 stub state — most words have
/// no image yet), renders a placeholder tile with the slug as text so the
/// child has SOMETHING visual to associate with the spoken word.
class ExampleWordOverlay extends StatefulWidget {
  const ExampleWordOverlay({
    super.key,
    required this.controller,
    this.visibleDuration = const Duration(seconds: 3),
    this.fadeDuration = const Duration(milliseconds: 300),
  });

  final ExampleWordOverlayController controller;
  final Duration visibleDuration;
  final Duration fadeDuration;

  @override
  State<ExampleWordOverlay> createState() => _ExampleWordOverlayState();
}

class _ExampleWordOverlayState extends State<ExampleWordOverlay> {
  String? _slug;
  double _opacity = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChange);
    super.dispose();
  }

  void _onControllerChange() {
    final slug = widget.controller.wordSlug;
    if (slug == null) {
      setState(() {
        _opacity = 0;
        _slug = null;
      });
      return;
    }
    setState(() {
      _slug = slug;
      _opacity = 1.0;
    });
    // After visibleDuration, fade out + clear.
    Future<void>.delayed(widget.visibleDuration, () {
      if (!mounted || widget.controller.wordSlug != slug) return;
      setState(() => _opacity = 0);
      Future<void>.delayed(widget.fadeDuration, () {
        if (!mounted) return;
        setState(() => _slug = null);
      });
    });
  }

  Future<bool> _imageExists(String slug) async {
    try {
      await rootBundle.load(exampleWordImagePath(slug));
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final slug = _slug;
    if (slug == null) return const SizedBox.shrink();
    return AnimatedOpacity(
      opacity: _opacity,
      duration: widget.fadeDuration,
      child: Center(
        child: FutureBuilder<bool>(
          future: _imageExists(slug),
          builder: (ctx, snap) {
            if (snap.data == true) {
              return Image.asset(
                exampleWordImagePath(slug),
                width: 320,
                height: 320,
              );
            }
            // Placeholder: text-on-color tile (D-12 fallback).
            return Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1B8),
                borderRadius: BorderRadius.circular(24),
              ),
              alignment: Alignment.center,
              child: Text(
                exampleWordPlaceholderText(slug),
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
