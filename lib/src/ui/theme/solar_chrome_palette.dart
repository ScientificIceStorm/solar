import 'package:flutter/material.dart';

import '../models/app_account.dart';

Color solarChromeAccentColor(
  AppChromeAccentPreference preference, {
  int? customAccentValue,
}) {
  switch (preference) {
    case AppChromeAccentPreference.midnight:
      return const Color(0xFF0F111A);
    case AppChromeAccentPreference.ocean:
      return const Color(0xFF0D3B66);
    case AppChromeAccentPreference.forest:
      return const Color(0xFF1D5C46);
    case AppChromeAccentPreference.sunset:
      return const Color(0xFF7A2E2A);
    case AppChromeAccentPreference.graphite:
      return const Color(0xFF2A2E37);
    case AppChromeAccentPreference.light:
      return const Color(0xFF5E78B2);
    case AppChromeAccentPreference.custom:
      return customAccentValue == null
          ? const Color(0xFF0F111A)
          : Color(customAccentValue);
  }
}

String solarChromeAccentLabel(AppChromeAccentPreference preference) {
  switch (preference) {
    case AppChromeAccentPreference.midnight:
      return 'Midnight';
    case AppChromeAccentPreference.ocean:
      return 'Ocean';
    case AppChromeAccentPreference.forest:
      return 'Forest';
    case AppChromeAccentPreference.sunset:
      return 'Sunset';
    case AppChromeAccentPreference.graphite:
      return 'Graphite';
    case AppChromeAccentPreference.light:
      return 'Light';
    case AppChromeAccentPreference.custom:
      return 'Custom';
  }
}
