import 'package:flutter/widgets.dart';

/// The single locale Hugrún supports. Per PROJECT.md "Localization beyond
/// Icelandic is explicitly out of scope."
const Locale kIcelandicLocale = Locale('is');

/// Supported locales list for MaterialApp.supportedLocales. Single-entry by design.
const List<Locale> kSupportedLocales = <Locale>[kIcelandicLocale];
