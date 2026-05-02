import 'package:flutter/material.dart';

/// Phase 1 placeholder. Phase 4 fills with child-name form (PERS-01..03).
/// 'Stillingar' is Icelandic for 'Settings' (D-24).
class ParentSettingsScreen extends StatelessWidget {
  const ParentSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Stillingar')),
      body: const Center(
        child: Text('Stillingar', style: TextStyle(fontSize: 24)),
      ),
    );
  }
}
