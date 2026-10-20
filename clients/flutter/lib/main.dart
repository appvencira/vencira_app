import 'package:flutter/material.dart';

import 'api/vencira_api.dart';
import 'ui/dashboard_screen.dart';

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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF145C75),
        ),
        useMaterial3: true,
      ),
      home: VenciraDashboardScreen(api: api),
    );
  }
}
