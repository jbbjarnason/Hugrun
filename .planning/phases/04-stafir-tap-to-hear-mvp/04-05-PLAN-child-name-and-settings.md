---
phase: 04-stafir-tap-to-hear-mvp
plan: 05
type: execute
wave: 2
depends_on: []
files_modified:
  - lib/features/parent_settings/child_name_provider.dart
  - lib/features/parent_settings/child_name_provider.g.dart
  - lib/features/parent_settings/parent_settings_screen.dart
  - test/features/parent_settings/child_name_provider_test.dart
  - test/features/parent_settings/parent_settings_screen_test.dart
  - integration_test/parent_settings_db_test.dart
autonomous: true
requirements:
  - PERS-01  # parent enters child's name; default "Hugrún"
  - PERS-02  # name persists in Drift across restart
tags:
  - flutter
  - riverpod
  - drift
  - phase-4

must_haves:
  truths:
    - "ChildNameProvider exposes the current child name as a Stream<String?> watched from Drift child_profiles"
    - "Default child name on first launch is 'Hugrún' (already enforced by Phase 1 ensureDefaultChildProfile)"
    - "ParentSettingsScreen shows a single TextField pre-filled with the current child name"
    - "ParentSettingsScreen has a 'Vista' (Save) button that writes the new name to Drift via child_profiles_dao.upsertName"
    - "After save, ChildNameProvider streams the updated value to all watchers (welcome narration in Plan 06 watches this)"
    - "Save validates: 1..32 chars, trimmed, non-empty after trim — matches the Drift table constraint"
    - "Empty/whitespace input on save shows an Icelandic-language error label and does NOT write to DB"
    - "Saved name survives an integration-test app restart (writes via DAO, reads via DAO after re-creating ChildProfilesDao)"
  artifacts:
    - path: "lib/features/parent_settings/child_name_provider.dart"
      provides: "Riverpod codegen Stream provider reading child_profiles_dao.watchLatest()"
      contains: "@riverpod"
    - path: "lib/features/parent_settings/parent_settings_screen.dart"
      provides: "ConsumerWidget with TextField + Vista button + Icelandic labels"
      min_lines: 80
    - path: "test/features/parent_settings/child_name_provider_test.dart"
      provides: "Provider tests using ProviderContainer + in-memory Drift"
      min_lines: 40
    - path: "integration_test/parent_settings_db_test.dart"
      provides: "Round-trip persistence test — write 'Hugrún' → 'Anna' → reopen DAO → read 'Anna'"
      min_lines: 30
  key_links:
    - from: "lib/features/parent_settings/child_name_provider.dart"
      to: "lib/core/db/dao/child_profiles_dao.dart"
      via: "watchLatest() Stream<ChildProfile?>"
      pattern: "watchLatest"
    - from: "lib/features/parent_settings/parent_settings_screen.dart"
      to: "lib/features/parent_settings/child_name_provider.dart"
      via: "ref.watch(childNameProvider)"
      pattern: "ref\\.watch\\(childNameProvider\\)"
    - from: "lib/features/parent_settings/parent_settings_screen.dart"
      to: "lib/core/db/dao/child_profiles_dao.dart"
      via: "ref.read(appDatabaseProvider).childProfilesDao.upsertName(name: ...)"
      pattern: "upsertName"
---

<objective>
Wire the parent-facing settings flow that captures the child's name. Phase 1 stubbed `ParentSettingsScreen` and shipped `child_profiles_dao.upsertName()` + `watchLatest()`; this plan fills the screen with the actual UI and exposes the name to the rest of Phase 4 via a Riverpod provider.

Why a separate plan from Plan 04 (StafirRoom): file ownership is disjoint. ParentSettingsScreen + child_name_provider don't touch any AudioEngine / Stafir / LetterTile files. Plan 05 can run in parallel with Plans 02-04 in Wave 2.

Why a separate plan from Plan 06 (welcome narration): welcome narration depends on BOTH AudioEngine.play (Plan 02) AND childNameProvider (Plan 05). Wave 3 brings them together.

Purpose:
- PERS-01: Parent enters child name. Default 'Hugrún' already exists from Phase 1 bootstrap.
- PERS-02: Persistence in Drift survives restart. Phase 1's child_profiles table + DAO already deliver this; Plan 05 wires the UI to it.
- (PERS-03 is owned by Plan 06 — welcome narration that uses the name.)

Output: A working settings screen + a reactive provider exposing the name.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/REQUIREMENTS.md
@.planning/ROADMAP.md

@.planning/phases/04-stafir-tap-to-hear-mvp/04-CONTEXT.md
@.planning/phases/01-skeleton-drift-schema/01-SUMMARY.md
@.planning/phases/01-skeleton-drift-schema/01-02-SUMMARY.md

@lib/core/db/database.dart
@lib/core/db/database_provider.dart
@lib/core/db/bootstrap.dart
@lib/core/db/dao/child_profiles_dao.dart
@lib/core/db/tables/child_profiles.dart
@lib/features/parent_settings/parent_settings_screen.dart

<interfaces>
<!-- Carry-forward from Phase 1 — already on disk. -->

From lib/core/db/dao/child_profiles_dao.dart:
```dart
class ChildProfilesDao extends DatabaseAccessor<AppDatabase> {
  Future<int> count();
  Future<ChildProfile?> readLatest();
  Stream<ChildProfile?> watchLatest();      // <- Plan 05 provider wraps this
  Future<void> upsertName({required String name}); // <- Plan 05 Save button calls this
}
```

From lib/core/db/tables/child_profiles.dart (constraint we honor):
```dart
TextColumn get name => text().withLength(min: 1, max: 32)();
```

From lib/core/db/bootstrap.dart (already invoked Phase 1):
```dart
Future<void> ensureDefaultChildProfile(AppDatabase db, {String defaultName = 'Hugrún'});
```

From lib/core/db/database_provider.dart:
```dart
@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref); // generated symbol: appDatabaseProvider
```

ChildProfile data class (drift codegen):
```dart
class ChildProfile {
  final int id;
  final String name;       // <- the field Plan 05 displays
  final DateTime createdAt;
}
```
</interfaces>

<reference_decisions>
- D-17: ParentSettingsScreen filled out:
  - One field: child's name. Default value from Drift child_profiles, default "Hugrún".
  - "Save" button writes to Drift via child_profiles_dao.
  - Parent-facing — Icelandic labels: 'Stillingar', 'Nafn barns', 'Vista'.
- D-20: Riverpod provider `childNameProvider` (auto-init from Drift child_profiles). Watched by ParentSettingsScreen + welcome narration logic in HomeScreen (Plan 06).
- D-21: Updating name via settings invalidates childNameProvider; if name changes between known states, the next welcome plays the matching variant. NO mid-session re-narration.
- D-25: Widget tests for ParentSettingsScreen save button writes to Drift.
- D-26: Integration test for full Stafir flow — Plan 07 owns this.
</reference_decisions>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: RED — write failing tests for childNameProvider + ParentSettingsScreen save flow + DB round-trip</name>
  <files>
    test/features/parent_settings/child_name_provider_test.dart,
    test/features/parent_settings/parent_settings_screen_test.dart,
    integration_test/parent_settings_db_test.dart
  </files>
  <behavior>
    test/features/parent_settings/child_name_provider_test.dart (uses in-memory Drift):
    - "childNameProvider returns 'Hugrún' on first read after ensureDefaultChildProfile" — bootstrap a fresh in-memory AppDatabase, override appDatabaseProvider, await first emission of childNameProvider, assert == 'Hugrún'
    - "childNameProvider streams updated value when DAO upsertName fires" — listen to provider, call dao.upsertName(name: 'Anna'), expect next value 'Anna'
    - "childNameProvider returns null when child_profiles is empty (defensive)" — fresh DB without bootstrap; expect first emission null

    test/features/parent_settings/parent_settings_screen_test.dart:
    - "ParentSettingsScreen shows AppBar with title 'Stillingar'" — preserved from Phase 1
    - "ParentSettingsScreen shows label 'Nafn barns'"
    - "ParentSettingsScreen pre-fills the TextField with the current child name from childNameProvider" — override provider with Stream that emits 'Hugrún', pump, assert TextField controller text == 'Hugrún'
    - "Tapping the 'Vista' button calls childProfilesDao.upsertName with the trimmed input" — type 'Anna', tap Vista, assert fake DAO records upsertName('Anna')
    - "Tapping 'Vista' with empty input shows Icelandic error 'Nafnið má ekki vera tómt' and does NOT call upsertName" — clear field, tap Vista
    - "Tapping 'Vista' with whitespace-only input is treated as empty"
    - "Tapping 'Vista' with name longer than 32 chars trims to 32 OR shows error 'Nafn má ekki vera lengra en 32 stafir'" — pick error path; document choice
    - "After successful save, the screen shows a transient confirmation 'Vistað ✓' for ~1 second" — accept SnackBar or inline; widget test asserts the text appears

    integration_test/parent_settings_db_test.dart (real Drift on real platform):
    - "Save 'Anna' on screen → close DB connection → reopen → DAO.readLatest returns 'Anna'" — uses NativeDatabase or in-memory file-backed; closes and reopens via a new AppDatabase instance pointing at the same file
  </behavior>
  <action>
    Write the three test files. Tests fail because:
    - childNameProvider doesn't exist
    - ParentSettingsScreen is still the Phase 1 placeholder

    Use a test helper for in-memory Drift setup. Phase 1's `01-02-SUMMARY.md` should mention the existing test helper; if none, create one at `test/features/parent_settings/_helpers/in_memory_db.dart` that constructs an AppDatabase backed by `NativeDatabase.memory()` and bootstraps the default profile.

    Atomic commit: `test(04-05): add failing tests for childNameProvider + ParentSettingsScreen save flow`
  </action>
  <verify>
    <automated>cd /Users/jonb/Projects/hugrun &amp;&amp; flutter test test/features/parent_settings/ 2>&amp;1 | tail -20</automated>
  </verify>
  <done>
    - 11+ new failing tests across the 3 files
    - Pre-existing tests still pass
    - Atomic commit landed
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: GREEN — implement childNameProvider + rewrite ParentSettingsScreen</name>
  <files>
    lib/features/parent_settings/child_name_provider.dart,
    lib/features/parent_settings/child_name_provider.g.dart,
    lib/features/parent_settings/parent_settings_screen.dart
  </files>
  <action>
    1. `lib/features/parent_settings/child_name_provider.dart`:
       ```dart
       import 'package:riverpod_annotation/riverpod_annotation.dart';
       import 'package:hugrun/core/db/database_provider.dart';

       part 'child_name_provider.g.dart';

       /// Streams the current child's name from Drift child_profiles.
       /// Returns null if the table is empty (defensive — bootstrap inserts
       /// 'Hugrún' on first launch, so production code rarely sees null).
       /// D-20: app-scoped (keepAlive: true) — settings screen + welcome
       /// narration both watch this.
       @Riverpod(keepAlive: true)
       Stream&lt;String?&gt; childName(Ref ref) {
         final db = ref.watch(appDatabaseProvider);
         return db.childProfilesDao.watchLatest().map((profile) =&gt; profile?.name);
       }
       ```
       Run `dart run build_runner build --delete-conflicting-outputs`. Generated `child_name_provider.g.dart` follows the same gitignore convention as Phase 1's appDatabaseProvider.g.dart.

    2. `lib/features/parent_settings/parent_settings_screen.dart` — rewrite:
       ```dart
       import 'package:flutter/material.dart';
       import 'package:flutter_riverpod/flutter_riverpod.dart';
       import 'package:hugrun/core/db/database_provider.dart';
       import 'child_name_provider.dart';

       /// Phase 4 D-17 / D-20 / PERS-01 + PERS-02. Replaces the Phase 1 stub.
       /// Icelandic labels (parent-facing, NOT child-facing — STAFIR-08 doesn't
       /// apply here because the child can't reach this screen without the
       /// 3-second parent gate).
       class ParentSettingsScreen extends ConsumerStatefulWidget {
         const ParentSettingsScreen({super.key});
         @override
         ConsumerState&lt;ParentSettingsScreen&gt; createState() =&gt; _ParentSettingsScreenState();
       }

       class _ParentSettingsScreenState extends ConsumerState&lt;ParentSettingsScreen&gt; {
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

         Future&lt;void&gt; _save() async {
           final raw = _ctl.text;
           final name = raw.trim();
           if (name.isEmpty) {
             setState(() =&gt; _error = 'Nafnið má ekki vera tómt');
             return;
           }
           if (name.length &gt; 32) {
             setState(() =&gt; _error = 'Nafn má ekki vera lengra en 32 stafir');
             return;
           }
           setState(() =&gt; _error = null);
           final db = ref.read(appDatabaseProvider);
           await db.childProfilesDao.upsertName(name: name);
           if (!mounted) return;
           setState(() =&gt; _showSaved = true);
           Future.delayed(const Duration(seconds: 1), () {
             if (mounted) setState(() =&gt; _showSaved = false);
           });
         }

         @override
         Widget build(BuildContext context) {
           final asyncName = ref.watch(childNameProvider);

           // One-shot pre-fill of the controller from the first emission.
           if (!_initialized) {
             asyncName.whenData((name) {
               if (name != null &amp;&amp; _ctl.text.isEmpty) {
                 _ctl.text = name;
                 _initialized = true;
               }
             });
           }

           return Scaffold(
             appBar: AppBar(title: const Text('Stillingar')),
             body: Padding(
               padding: const EdgeInsets.all(24),
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   const Text('Nafn barns', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                   const SizedBox(height: 8),
                   TextField(
                     controller: _ctl,
                     maxLength: 32,
                     decoration: InputDecoration(
                       border: const OutlineInputBorder(),
                       errorText: _error,
                     ),
                   ),
                   const SizedBox(height: 16),
                   FilledButton(
                     key: const Key('parent-settings-vista'),
                     onPressed: _save,
                     child: const Text('Vista'),
                   ),
                   const SizedBox(height: 16),
                   if (_showSaved) const Text('Vistað ✓', key: Key('parent-settings-saved-confirm')),
                 ],
               ),
             ),
           );
         }
       }
       ```

    Run `flutter test test/features/parent_settings/`; all should pass.
    Run `flutter test integration_test/parent_settings_db_test.dart` — note: integration tests under `integration_test/` typically run via `flutter test integration_test/` against a device or `flutter drive`. Confirm the existing CI pattern (Phase 1 has `integration_test/no_network_test.dart` and `database_smoke_test.dart` already) and follow it.

    Atomic commit: `feat(04-05): childNameProvider + ParentSettingsScreen with name field + Vista save (D-17, D-20, PERS-01, PERS-02)`
  </action>
  <verify>
    <automated>cd /Users/jonb/Projects/hugrun &amp;&amp; flutter test &amp;&amp; flutter analyze</automated>
  </verify>
  <done>
    - All Task 1 tests green
    - Pre-existing tests still green
    - `flutter analyze` clean
    - Atomic commit landed
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 3: REFACTOR — extract validation + Icelandic copy constants</name>
  <files>
    lib/features/parent_settings/parent_settings_screen.dart,
    lib/features/parent_settings/parent_settings_strings.dart
  </files>
  <action>
    With tests green, polish:

    Create `lib/features/parent_settings/parent_settings_strings.dart`:
    ```dart
    /// Parent-facing Icelandic copy. Centralized so future localization +
    /// review by a native speaker is a single-file diff.
    abstract class ParentSettingsStrings {
      static const String title = 'Stillingar';
      static const String childNameLabel = 'Nafn barns';
      static const String saveButton = 'Vista';
      static const String savedConfirmation = 'Vistað ✓';
      static const String errorEmpty = 'Nafnið má ekki vera tómt';
      static const String errorTooLong = 'Nafn má ekki vera lengra en 32 stafir';
    }
    ```

    Update parent_settings_screen.dart to reference the constants. Run tests; assert nothing breaks.

    Extract validation:
    ```dart
    /// Pure function — testable without a widget tree.
    String? validateChildName(String raw) {
      final name = raw.trim();
      if (name.isEmpty) return ParentSettingsStrings.errorEmpty;
      if (name.length > 32) return ParentSettingsStrings.errorTooLong;
      return null;
    }
    ```
    Add unit tests for `validateChildName` covering the same edge cases as the widget test (empty, whitespace, 32 chars exactly, 33 chars). Replace the inline validation in `_save` with a call to `validateChildName`.

    Atomic commit: `refactor(04-05): extract Icelandic copy constants + validateChildName for testability`
  </action>
  <verify>
    <automated>cd /Users/jonb/Projects/hugrun &amp;&amp; flutter test &amp;&amp; flutter analyze</automated>
  </verify>
  <done>
    - All tests green
    - `flutter analyze` clean
    - Atomic commit landed
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| parent → TextField | parent-typed text crosses into the app (not adversarial — it's the device owner) |
| ParentSettingsScreen → Drift | UI writes go to local SQLite via DAO |
| Drift file → process | DB file at app sandbox path |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-04-16 | T (tampering) | malformed name input (oversize, control chars) | mitigate | validateChildName trims + length-checks; Drift table column has `min: 1, max: 32` constraint as last line of defense |
| T-04-17 | I (info disclosure) | child name leaked in logs | mitigate | no debugPrint of name in this plan; welcome narration in Plan 06 reads via provider, never logs |
| T-04-18 | E (elevation) | UI written without parent gate | accept | Phase 1's HomePage already wraps the settings entry in ParentGate (3 s hold). Plan 05 doesn't change navigation; it only fills the screen |
| T-04-19 | T (tampering) | empty/whitespace name accepted | mitigate | validateChildName + DB column constraint; widget test asserts Save with empty input shows error AND does NOT call upsertName |
</threat_model>

<verification>
- `flutter test` — all green (≥138 tests)
- `flutter analyze` — 0 issues
- `dart format --set-exit-if-changed .` — clean
- `flutter test integration_test/parent_settings_db_test.dart` — passes against device or simulator (CI: matches Phase 1 integration_test pattern)
- `flutter build apk --debug` — succeeds
</verification>

<success_criteria>
- ChildNameProvider exists, streams from Drift, defaults to 'Hugrún'
- ParentSettingsScreen captures + saves the child's name with validation + Icelandic copy
- Round-trip persistence verified via integration test
- 11+ new tests + integration test
- 3 atomic commits (RED → GREEN → REFACTOR)
</success_criteria>

<output>
Create `.planning/phases/04-stafir-tap-to-hear-mvp/04-05-SUMMARY.md` with:
- ChildNameProvider + ParentSettingsScreen public API
- Icelandic copy table (label → translation → review status)
- Decisions exercised: D-17, D-20, D-21
- Requirements satisfied: PERS-01, PERS-02 (PERS-03 lands in Plan 06)
- Test count delta
- Atomic commits + SHAs
- Note on the integration_test execution model (CI vs local)
</output>
