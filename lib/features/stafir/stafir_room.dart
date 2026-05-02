import 'package:flutter/material.dart';

/// Phase 1 placeholder for the Stafir (Letters) room.
/// Phase 2 lands the 32-letter alphabet constant; Phase 4 fills the body
/// with the tap-to-hear letter grid (STAFIR-01..10).
class StafirRoom extends StatelessWidget {
  const StafirRoom({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Stafir')),
      body: const Center(child: Text('Stafir', style: TextStyle(fontSize: 32))),
    );
  }
}
