import 'package:flutter/material.dart';

import '../api/native_session_coordinator.dart';
import '../ui/native_login_screen.dart';

/// G7: UI-to-coordinator wiring for isolated Android/iOS login tests.
///
/// A port backed by a reviewed password/MFA issuer MUST be supplied by a
/// test harness. This shell never creates credentials, HTTP endpoints, a
/// default account, or a production session. No workspace data is exposed.
class NativeLabLoginShell extends StatefulWidget {
  const NativeLabLoginShell({super.key, required this.coordinator});

  final NativeSessionCoordinator coordinator;

  @override
  State<NativeLabLoginShell> createState() => _NativeLabLoginShellState();
}

class _NativeLabLoginShellState extends State<NativeLabLoginShell> {
  bool _authenticated = false;
  bool _working = false;
  String? _error;
  int _transition = 0;

  void _onAuthenticated() {
    if (!mounted || _working || widget.coordinator.fence.ticket == null) {
      return;
    }
    setState(() {
      _authenticated = true;
      _error = null;
    });
  }

  Future<void> _logout() async {
    if (_working) return;
    final transition = ++_transition;
    // The coordinator revokes its request fence synchronously before any
    // awaited server or protected-storage operation.
    final cleanup = widget.coordinator.logout();
    setState(() {
      _authenticated = false;
      _working = true;
      _error = null;
    });
    try {
      await cleanup;
      if (!mounted || transition != _transition) return;
      setState(() => _working = false);
    } catch (_) {
      if (!mounted || transition != _transition) return;
      setState(() {
        _working = false;
        _error = 'No se pudo completar el cierre de sesión.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_authenticated && !_working && _error == null) {
      return NativeLoginScreen(
        key: const Key('g7-native-login'),
        gateway: widget.coordinator,
        onAuthenticated: _onAuthenticated,
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('VENCIRA · laboratorio')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.phonelink_lock_outlined, size: 42),
                  const SizedBox(height: 20),
                  Text(
                    _authenticated &&
                            widget.coordinator.fence.ticket != null
                        ? 'Sesión nativa de laboratorio'
                        : 'Acceso bloqueado',
                    key: const Key('g7-native-status'),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Entorno aislado: sin acceso a datos operativos. '
                    'Este ensayo no habilita autenticación de producción.',
                    textAlign: TextAlign.center,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      key: const Key('g7-native-logout-error'),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 20),
                  if (_working)
                    const Center(child: CircularProgressIndicator())
                  else if (_authenticated &&
                      widget.coordinator.fence.ticket != null)
                    FilledButton(
                      key: const Key('g7-native-logout'),
                      onPressed: _logout,
                      child: const Text('Cerrar sesión'),
                    )
                  else
                    FilledButton(
                      key: const Key('g7-native-retry-logout'),
                      onPressed: _logout,
                      child: const Text('Reintentar cierre seguro'),
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
