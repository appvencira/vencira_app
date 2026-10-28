import 'package:flutter/material.dart';

/// Estado compartido de presentación: ni contraseñas ni datos de clientes.
class VenciraPreferences extends InheritedWidget {
  const VenciraPreferences({
    super.key,
    required super.child,
    required this.themeMode,
    required this.locale,
    required this.setThemeMode,
    required this.setLocale,
  });

  final ThemeMode themeMode;
  final Locale locale;
  final ValueChanged<ThemeMode> setThemeMode;
  final ValueChanged<Locale> setLocale;

  static VenciraPreferences of(BuildContext context) {
    final value = context.dependOnInheritedWidgetOfExactType<VenciraPreferences>();
    assert(value != null, 'VenciraPreferences is missing');
    return value!;
  }

  @override
  bool updateShouldNotify(VenciraPreferences oldWidget) =>
      themeMode != oldWidget.themeMode || locale != oldWidget.locale;
}
