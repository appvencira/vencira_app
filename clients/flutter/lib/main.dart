import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api/vencira_api.dart';
import 'notifications/device_notice_revocation.dart';
import 'notifications/device_notice_startup_gate.dart';
import 'l10n/app_localizations.dart';
import 'ui/dashboard_screen.dart';
import 'ui/android_web_access_screen.dart';
import 'ui/vencira_theme.dart';
import 'ui/vencira_preferences.dart';

void main() => runApp(const VenciraApp());

class VenciraApp extends StatefulWidget {
  const VenciraApp({super.key, this.api});

  /// Inyección de datos simulados solo para pruebas automáticas.
  final VenciraApi? api;

  @override
  State<VenciraApp> createState() => _VenciraAppState();
}

class _VenciraAppState extends State<VenciraApp> {
  static const _themeKey = 'vencira.ui.theme.v1';
  static const _localeKey = 'vencira.ui.locale.v1';

  ThemeMode _themeMode = ThemeMode.system;
  Locale _locale = const Locale('es');
  bool _themeChangedByUser = false;
  bool _localeChangedByUser = false;

  // Share a single cancellation operation between startup, session expiry,
  // account switch and logout. Do not run native OS changes concurrently.
  Future<void>? _nativeRevocationInProgress;

  Future<void> _revokeNativeAlarms() {
    final running = _nativeRevocationInProgress;
    if (running != null) return running;
    final completer = Completer<void>();
    _nativeRevocationInProgress = completer.future;
    () async {
      try {
        await revokePersistedAndroidAlarms();
        completer.complete();
      } catch (error, stack) {
        completer.completeError(error, stack);
      } finally {
        _nativeRevocationInProgress = null;
      }
    }();
    return completer.future;
  }


  @override
  void initState() {
    super.initState();
    _restorePreferences();
  }

  Future<void> _restorePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      final savedTheme = prefs.getString(_themeKey);
      final savedLocale = prefs.getString(_localeKey);
      setState(() {
        // No sobrescribir elecciones hechas mientras se leía el almacenamiento.
        if (!_themeChangedByUser) {
          _themeMode = switch (savedTheme) {
            'light' => ThemeMode.light,
            'dark' => ThemeMode.dark,
            _ => ThemeMode.system,
          };
        }
        if (!_localeChangedByUser) {
          _locale = Locale(savedLocale == 'ca' ? 'ca' : 'es');
        }
      });
    } catch (_) {
      // Preferencias opcionales: el fallo de almacenamiento no bloquea la app.
    }
  }

  void _setThemeMode(ThemeMode value) {
    _themeChangedByUser = true;
    setState(() => _themeMode = value);
    _saveTheme(value);
  }

  Future<void> _saveTheme(ThemeMode value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeKey, value.name);
    } catch (_) {
      // El cambio inmediato permanece válido aunque falle el almacenamiento.
    }
  }

  void _setLocale(Locale value) {
    if (value.languageCode != 'es' && value.languageCode != 'ca') return;
    _localeChangedByUser = true;
    setState(() => _locale = value);
    _saveLocale(value);
  }

  Future<void> _saveLocale(Locale value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_localeKey, value.languageCode);
    } catch (_) {
      // La interfaz permanece disponible en el idioma elegido.
    }
  }

  @override
  Widget build(BuildContext context) {
    return VenciraPreferences(
      themeMode: _themeMode,
      locale: _locale,
      setThemeMode: _setThemeMode,
      setLocale: _setLocale,
      child: MaterialApp(
        title: 'VENCIRA',
        debugShowCheckedModeBanner: false,
        theme: VenciraTheme.light(),
        darkTheme: VenciraTheme.dark(),
        themeMode: _themeMode,
        locale: _locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        home: DeviceNoticeStartupGate(
          // This gate is active only for the real Android application.
          // No authenticated API calls may start before native cancellation
          // of prior-session alarms succeeds, or the user retries.
          enabled: widget.api == null && !kIsWeb &&
              defaultTargetPlatform == TargetPlatform.android,
          cancelPreviousAlarms: _revokeNativeAlarms,
          child: widget.api == null && !kIsWeb &&
                  defaultTargetPlatform == TargetPlatform.android
              ? const AndroidWebAccessScreen()
              : VenciraDashboardScreen(
            api: widget.api,
            openTodayOnLoad: widget.api == null,
            // Never schedule on startup; this only cancels. Expired sessions,
            // logout and workspace changes share the exact same gate.
            beforeSessionBoundary: widget.api == null
                ? _revokeNativeAlarms : null,
          ),
        ),
      ),
    );
  }
}
