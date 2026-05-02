import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database_provider.dart';
import 'child_name_provider.dart';
import 'photo_upload/photo_upload_screen.dart';

/// Phase 4 D-17 / D-20 / PERS-01 + PERS-02. Replaces the Phase 1 stub.
///
/// Parent-facing — Icelandic labels (`Stillingar`, `Nafn barns`, `Vista`).
/// STAFIR-08 ("zero text instructions visible to child") doesn't apply
/// here because the child can't reach this screen without the 3-second
/// parent gate (Phase 1 ParentGate primitive).
class ParentSettingsScreen extends ConsumerStatefulWidget {
  const ParentSettingsScreen({super.key});

  @override
  ConsumerState<ParentSettingsScreen> createState() =>
      _ParentSettingsScreenState();
}

class _ParentSettingsScreenState extends ConsumerState<ParentSettingsScreen> {
  late final TextEditingController _ctl;
  String? _error;
  bool _showSaved = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _ctl = TextEditingController();
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final raw = _ctl.text;
    final validationError = validateChildName(raw);
    if (validationError != null) {
      setState(() => _error = validationError);
      return;
    }
    setState(() => _error = null);
    final name = raw.trim();
    final db = ref.read(appDatabaseProvider);
    await db.childProfilesDao.upsertName(name: name);
    if (!mounted) return;
    setState(() => _showSaved = true);
    Future<void>.delayed(const Duration(seconds: 1), () {
      if (mounted) setState(() => _showSaved = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final asyncName = ref.watch(childNameProvider);

    // One-shot pre-fill of the controller from the first non-null emission.
    if (!_initialized) {
      asyncName.whenData((name) {
        if (name != null && _ctl.text.isEmpty) {
          _ctl.text = name;
          _initialized = true;
        }
      });
    }

    return Scaffold(
      appBar: AppBar(title: const Text(ParentSettingsStrings.title)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              ParentSettingsStrings.childNameLabel,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _ctl,
              // No maxLength input cap — validation happens at save time so
              // the user sees a clear error message if they paste >32 chars,
              // rather than silently truncating their input mid-typing.
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                errorText: _error,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('parent-settings-vista'),
              onPressed: _save,
              child: const Text(ParentSettingsStrings.saveButton),
            ),
            const SizedBox(height: 16),
            if (_showSaved)
              const Text(
                ParentSettingsStrings.savedConfirmation,
                key: Key('parent-settings-saved-confirm'),
              ),
            const SizedBox(height: 32),
            // Phase 10 D-08: Myndir entry — opens PhotoUploadScreen.
            FilledButton.tonalIcon(
              key: const Key('parent-settings-myndir'),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const PhotoUploadScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.photo_library),
              label: const Text(ParentSettingsStrings.photosButton),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pure validation. Tested independently in
/// `test/features/parent_settings/parent_settings_screen_test.dart`.
///
/// - empty / whitespace-only → error message
/// - >32 chars → error message
/// - else → null (valid)
String? validateChildName(String raw) {
  final name = raw.trim();
  if (name.isEmpty) return ParentSettingsStrings.errorEmpty;
  if (name.length > 32) return ParentSettingsStrings.errorTooLong;
  return null;
}

/// Parent-facing Icelandic copy. Centralized for future review by a native
/// speaker. Not localized — Hugrún is Icelandic-only by project constraint.
abstract class ParentSettingsStrings {
  static const String title = 'Stillingar';
  static const String childNameLabel = 'Nafn barns';
  static const String saveButton = 'Vista';
  static const String savedConfirmation = 'Vistað ✓';
  static const String errorEmpty = 'Nafnið má ekki vera tómt';
  static const String errorTooLong = 'Nafn má ekki vera lengra en 32 stafir';
  // Phase 10 D-08
  static const String photosButton = 'Myndir';
}
