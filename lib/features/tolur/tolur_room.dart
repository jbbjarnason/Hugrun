import 'package:flutter/material.dart';

/// Phase 1 placeholder for the Tölur (Numbers) room.
/// Phase 8 fills the body with the digit grid (NUM-01..03).
class TolurRoom extends StatelessWidget {
  const TolurRoom({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tölur')),
      body: const Center(child: Text('Tölur', style: TextStyle(fontSize: 32))),
    );
  }
}
