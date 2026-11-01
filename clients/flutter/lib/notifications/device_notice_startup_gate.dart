import 'package:flutter/material.dart';

/// Startup security barrier: native alarm cleanup must finish before a
/// dashboard can make authenticated API calls or expose another account.
/// This is intentionally cancellation-only; it cannot create notifications.
/// When cleanup fails, the encrypted inventory is retained and the user
/// must retry; there is no "skip" option.
class DeviceNoticeStartupGate extends StatefulWidget {
  const DeviceNoticeStartupGate({
    super.key,
    required this.child,
    required this.cancelPreviousAlarms,
    this.enabled = true,
  });

  final Widget child;
  final Future<void> Function() cancelPreviousAlarms;
  final bool enabled;

  @override
  State<DeviceNoticeStartupGate> createState() =>
      _DeviceNoticeStartupGateState();
}

class _DeviceNoticeStartupGateState extends State<DeviceNoticeStartupGate> {
  bool _ready = false;
  bool _busy = false;
  bool _failed = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _ready = !widget.enabled;
    if (widget.enabled) _run();
  }

  Future<void> _run() async {
    if (_busy || _ready) return;
    final current = ++_generation;
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      await widget.cancelPreviousAlarms();
      if (!mounted || current != _generation) return;
      setState(() {
        _ready = true;
        _busy = false;
      });
    } catch (_) {
      if (!mounted || current != _generation) return;
      setState(() {
        _busy = false;
        _failed = true;
      });
    }
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return widget.child;
    final ca = Localizations.localeOf(context).languageCode == 'ca';
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.phonelink_lock_outlined, size: 42,
                    color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 18),
                  Text(ca ? 'Protecció dels avisos locals'
                      : 'Protección de los avisos locales',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 10),
                  Text(_failed
                    ? (ca
                      ? 'No s’han pogut cancel·lar els avisos de la sessió anterior. Cal reintentar-ho per continuar.'
                      : 'No se han podido cancelar los avisos de la sesión anterior. Es necesario reintentarlo para continuar.')
                    : (ca
                      ? 'Comprovant els avisos pendents del dispositiu.'
                      : 'Comprobando los avisos pendientes del dispositivo.'),
                    textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  if (_busy) const CircularProgressIndicator(),
                  if (_failed) FilledButton.icon(
                    key: const ValueKey('retry-native-alarm-recovery'),
                    onPressed: _run,
                    icon: const Icon(Icons.refresh),
                    label: Text(ca ? 'Tornar-ho a intentar' : 'Reintentar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
