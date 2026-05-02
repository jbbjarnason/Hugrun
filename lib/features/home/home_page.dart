import 'package:flutter/material.dart';

/// Placeholder home page. Plan 01-03 replaces the body with the two-room
/// (Stafir / Tölur) shell + parent gate to ParentSettingsScreen. Lives here
/// now so widget tests can compile and the app can run end-to-end.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Hugrún', textDirection: TextDirection.ltr)),
    );
  }
}
