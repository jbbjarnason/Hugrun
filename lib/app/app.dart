import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../features/home/home_page.dart';
import 'locale.dart';

/// Root MaterialApp. Icelandic-only locale per project constraint.
/// Title shown in app launcher metadata; the launcher label itself comes
/// from native manifests (Info.plist / AndroidManifest.xml).
class HugrunApp extends StatelessWidget {
  const HugrunApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Hugrún',
      locale: kIcelandicLocale,
      supportedLocales: kSupportedLocales,
      localizationsDelegates: <LocalizationsDelegate<Object>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}
