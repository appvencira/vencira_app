// I8-H disposable Android + PG17 HTTPS. NEVER operational main.dart.
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'i8h_lab/physical_mfa_checks.dart';

const _enabled = bool.fromEnvironment('VENCIRA_I8H_LAB_BUILD');
const _ca = String.fromEnvironment('I8H_PUBLIC_CA_BASE64');

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (kReleaseMode || kIsWeb || !Platform.isAndroid || !_enabled ||
      _ca.isEmpty) {
    throw StateError('NATIVE_I8H_DEBUG_PHYSICAL_LAB_ONLY');
  }
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: I8hLabHome(),
  ));
}

class I8hLabHome extends StatefulWidget {
  const I8hLabHome({super.key});
  @override
  State<I8hLabHome> createState() => _I8hLabHomeState();
}

class _I8hLabHomeState extends State<I8hLabHome> {
  bool busy = false;
  String outcome = 'NATIVE_I8H_ANDROID_NOT_RUN';

  Future<void> _run(Future<List<String>> Function() work) async {
    if (busy) return;
    setState(() { busy = true; outcome = 'NATIVE_I8H_RUNNING'; });
    try {
      final records = await work();
      if (mounted) setState(() => outcome = records.join('\n'));
    } catch (_) {
      // No exception text, certificate, token, password, username or
      // server address may enter the screenshot/log.
      if (mounted) setState(() => outcome = 'NATIVE_I8H_ANDROID_GATE=FAIL');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<List<String>> _clean() async {
    await cleanPhysicalLab();
    return const ['NATIVE_I8H_ANDROID_SYNTHETIC_STORAGE_CLEAN=PASS'];
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('VENCIRA · I8-H Android')),
    body: SafeArea(child: ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const Text('MFA + HTTPS + almacenamiento Android',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 21)),
        const SizedBox(height: 12),
        const Text('Solo cuenta sintética, PostgreSQL temporal, certificado '
          'de laboratorio y túnel privado Android 127.0.0.1:18743. '
          'No hay acceso al servidor operativo.'),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: busy ? null : () => _run(runPhysicalMfa),
          child: const Text('Ejecutar prueba integral I8-H'),
        ),
        const SizedBox(height: 10),
        const Text('La prueba verifica TLS, MFA, almacenamiento protegido '
          'del refresh y revocación remota. Una ejecución incompleta '
          'permanece bloqueada para evitar una emisión ambigua.'),
        const SizedBox(height: 18),
        OutlinedButton(
          onPressed: busy ? null : () => _run(_clean),
          child: const Text('Limpiar laboratorio tras detener el servidor'),
        ),
        const SizedBox(height: 16),
        SelectableText(outcome,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5)),
        const SizedBox(height: 20),
        const Text('DEBUG sintético. No acredita recuperación total ni '
          'autoriza despliegue, migración o publicación.'),
      ],
    )),
  );
}
