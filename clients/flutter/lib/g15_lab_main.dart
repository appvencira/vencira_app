// Separate G15 debug-only APK. All checks are offline and synthetic.
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'g15_lab/physical_notice_checks.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (!g15LabEnabled || kReleaseMode || !Platform.isAndroid) {
    throw StateError('G15_ANDROID_DEBUG_ONLY');
  }
  runApp(const G15LabApp());
}

class G15LabApp extends StatelessWidget {
  const G15LabApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'VENCIRA G15 Avisos',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF176B81),
      ),
    ),
    home: const _G15Home(),
  );
}

class _G15Home extends StatefulWidget {
  const _G15Home();
  @override
  State<_G15Home> createState() => _G15HomeState();
}

class _G15HomeState extends State<_G15Home> {
  final _checks = G15PhysicalNoticeCheck();
  bool _busy = false;
  List<String> _markers = const [];
  String? _error;

  Future<void> _perform(Future<List<String>> Function() work) async {
    if (_busy) return;
    setState(() { _busy = true; _error = null; _markers = const []; });
    try {
      final markers = await work();
      if (mounted) setState(() => _markers = markers);
    } catch (error) {
      if (mounted) {
        setState(() => _error = error is StateError &&
                error.message.toString().startsWith('G15_')
            ? error.message.toString() : 'G15_ANDROID_ACTION_DENIED');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('VENCIRA · G15 LAB')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Avisos sintéticos Android',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          const Text(
            'Laboratorio independiente. No hay usuarios, servidor, '
            'contraseñas ni información de clientes. La solicitud de '
            'permiso solo aparece al pulsar el botón.',
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _busy ? null :
                () => _perform(_checks.requestPermission),
            icon: const Icon(Icons.notifications_active_outlined),
            label: const Text('1 · Solicitar permiso de avisos'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _busy ? null :
                () => _perform(_checks.checkPermission),
            icon: const Icon(Icons.fact_check_outlined),
            label: const Text('Comprobar permiso actual'),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: _busy ? null :
                () => _perform(_checks.scheduleSyntheticNotice),
            icon: const Icon(Icons.schedule_outlined),
            label: const Text('2 · Programar aviso de prueba (+15 min)'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _busy ? null :
                () => _perform(_checks.pendingState),
            icon: const Icon(Icons.search_outlined),
            label: const Text('3 · Consultar si queda pendiente'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _busy ? null :
                () => _perform(_checks.cancelSyntheticNotice),
            icon: const Icon(Icons.notifications_off_outlined),
            label: const Text('Cancelar aviso de prueba'),
          ),
          const SizedBox(height: 16),
          const Text(
            'Para el ensayo de reinicio: programa el aviso, reinicia '
            'el teléfono y comprueba manualmente si se entrega. No se '
            'garantiza la hora exacta: Android puede retrasarlo. '
            'Después, cancela cualquier aviso restante. Si deniegas '
            'o retiras el permiso en Ajustes, vuelve a comprobarlo: '
            'el laboratorio debe bloquear nuevas programaciones.',
          ),
          if (_busy) const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
          if (_error != null) Padding(
            padding: const EdgeInsets.only(top: 16),
            child: SelectableText('ERROR: ${_error!}'),
          ),
          if (_markers.isNotEmpty) Padding(
            padding: const EdgeInsets.only(top: 16),
            child: SelectableText(_markers.join('\n'),
                style: const TextStyle(fontFamily: 'monospace')),
          ),
          const SizedBox(height: 16),
          const Text(
            'Un PASS de este ensayo no autoriza la beta con datos reales '
            'ni verifica la recuperación de credenciales.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    ),
  );
}
