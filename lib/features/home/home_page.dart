import 'package:flutter/material.dart';

import '../../core/parent_gate/parent_gate.dart';
import '../parent_settings/parent_settings_screen.dart';
import '../stafir/stafir_room.dart';
import '../tolur/tolur_room.dart';
import 'room_button.dart';

/// Two-room home shell (FOUND-08) with a parent-gate-protected entry to
/// settings (FOUND-09). Both rooms are Phase 1 placeholders; Phase 4
/// (Stafir) and Phase 8 (Tölur) fill them. Navigator 1.0 (D-25).
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hugrún'),
        actions: <Widget>[
          // Parent-gate-wrapped settings entry. Hold 3 s to open.
          ParentGate(
            onCompleted: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ParentSettingsScreen(),
                ),
              );
            },
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Icon(Icons.settings, size: 32),
            ),
          ),
        ],
      ),
      body: const SafeArea(child: Center(child: _RoomGrid())),
    );
  }
}

class _RoomGrid extends StatelessWidget {
  const _RoomGrid();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 600;
        final children = <Widget>[
          RoomButton(
            key: const Key('home-room-stafir'),
            label: 'Stafir',
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => const StafirRoom())),
          ),
          RoomButton(
            key: const Key('home-room-tolur'),
            label: 'Tölur',
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => const TolurRoom())),
          ),
        ];
        return isWide
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: children,
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: children,
              );
      },
    );
  }
}
