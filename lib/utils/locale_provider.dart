import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kLocalePrefKey = 'app_locale';

class LocaleNotifier extends Notifier<Locale> {
  @override
  Locale build() {
    _loadSavedLocale();
    // 預設先依據系統/瀏覽器語系自動判斷，若無則為繁體中文
    final systemLanguage = PlatformDispatcher.instance.locale.languageCode.toLowerCase();
    if (systemLanguage.startsWith('en')) {
      return const Locale('en');
    }
    return const Locale('zh');
  }

  Future<void> _loadSavedLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCode = prefs.getString(_kLocalePrefKey);
    if (savedCode != null && (savedCode == 'en' || savedCode == 'zh')) {
      state = Locale(savedCode);
    }
  }

  Future<void> setLocale(Locale newLocale) async {
    if (state == newLocale) return;
    state = newLocale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLocalePrefKey, newLocale.languageCode);
  }

  Future<void> toggleLocale() async {
    final next = state.languageCode == 'zh' ? const Locale('en') : const Locale('zh');
    await setLocale(next);
  }
}

final localeProvider = NotifierProvider<LocaleNotifier, Locale>(() {
  return LocaleNotifier();
});

extension LocalizationExtension on BuildContext {
  AppLocalizations get l10n {
    return AppLocalizations.of(this)!;
  }
}
