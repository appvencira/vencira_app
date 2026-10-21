import 'package:flutter/material.dart';

import 'api/vencira_api.dart';
import 'ui/dashboard_screen.dart';
import 'ui/vencira_theme.dart';

void main() => runApp(const VenciraApp());

class VenciraApp extends StatelessWidget {
  const VenciraApp({super.key, this.api});

  /// Inyección de datos simulados solo para pruebas automáticas.
  final VenciraApi? api;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VENCIRA',
      debugShowCheckedModeBanner: false,
      theme: VenciraTheme.light(),
      darkTheme: VenciraTheme.dark(),
      themeMode: ThemeMode.system,
      home: VenciraDashboardScreen(api: api),
    );
  }
}
