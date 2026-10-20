import 'package:flutter/material.dart';

void main() => runApp(const VenciraApp());

class VenciraApp extends StatelessWidget {
  const VenciraApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'VENCIRA',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF145C75)),
          useMaterial3: true,
        ),
        home: const DashboardScreen(),
      );
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('VENCIRA')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: const Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Anticipa cada vencimiento', style: TextStyle(fontSize: 26)),
                  SizedBox(height: 12),
                  Text('Anticipamos vencimientos. Creamos oportunidades.'),
                  SizedBox(height: 24),
                  Card(child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Aún no hay vencimientos. Esta versión es una base técnica, sin acceso a datos de clientes.'),
                  )),
                ],
              ),
            ),
          ),
        ),
      );
}
