import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api/vencira_api.dart';
import 'l10n/app_localizations.dart';
import 'ui/dashboard_screen.dart';
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
        home: VenciraDashboardScreen(api: widget.api),
      ),
    );
  }
}
