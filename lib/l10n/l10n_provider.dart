import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_localizations.dart';
import '../providers/locale_provider.dart';

final l10nProvider = Provider<AppLocalizations>((ref) {
  final locale = ref.watch(localeProvider) ?? PlatformDispatcher.instance.locale;
  
  // Try to find a supported locale
  Locale supportedLocale = const Locale('en');
  for (final l in AppLocalizations.supportedLocales) {
    if (l.languageCode == locale.languageCode) {
      supportedLocale = l;
      break;
    }
  }
  
  return lookupAppLocalizations(supportedLocale);
});
