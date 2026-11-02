import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The screen cannot authenticate by itself. The future reviewed native
/// session coordinator must implement these operations and return
/// [NativePasswordDecision.authenticated] only after server verification,
/// refresh credential vault persistence and session-fence activation.
enum NativePasswordDecision { authenticated, mfaRequired }

abstract class NativeLoginGateway {
  Future<NativePasswordDecision> verifyPassword({
    required String username,
    required String password,
  });

  /// Succeeds only after challenge consumption, MFA checks, server token
  /// issuance, protected refresh write and activation of the session fence.
  Future<void> verifyTotp(String code);

  /// Discard a pending challenge without creating a native session.
  Future<void> abandonChallenge();
}

/// Browserless Android/iOS login presentation; NOT routed from main.dart.
/// Until a reviewed NativeLoginGateway exists, only synthetic widget tests
/// may instantiate this screen. Never display or log tokens here.
class NativeLoginScreen extends StatefulWidget {
  const NativeLoginScreen({
    super.key,
    required this.gateway,
    required this.onAuthenticated,
  });

  final NativeLoginGateway gateway;
  final VoidCallback onAuthenticated;

  @override
  State<NativeLoginScreen> createState() => _NativeLoginScreenState();
}

class _NativeLoginScreenState extends State<NativeLoginScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _totp = TextEditingController();
  int _requestEpoch = 0;
  bool _busy = false;
  bool _mfa = false;
  String? _error;

  @override
  void dispose() {
    _requestEpoch++;
    _username.dispose();
    _password.dispose();
    _totp.dispose();
    super.dispose();
  }

  Future<void> _submitPassword() async {
    if (_busy || _mfa) return;
    final username = _username.text.trim();
    final password = _password.text;
    if (username.isEmpty || username.length > 150 ||
        password.isEmpty || password.length > 4096) {
      setState(() => _error = 'Introduce tus datos de acceso.');
      return;
    }
    final ticket = ++_requestEpoch;
    setState(() {
      _busy = true;
      _error = null;
    });
    // A password must not be retained by the UI after submission.
    _password.clear();
    try {
      final decision = await widget.gateway.verifyPassword(
        username: username,
        password: password,
      );
      if (!mounted || ticket != _requestEpoch) return;
      if (decision == NativePasswordDecision.mfaRequired) {
        setState(() {
          _mfa = true;
          _busy = false;
          _error = null;
        });
      } else {
        setState(() => _busy = false);
        widget.onAuthenticated();
      }
    } catch (_) {
      if (!mounted || ticket != _requestEpoch) return;
      setState(() {
        _busy = false;
        _error = 'No se ha podido verificar el acceso.';
      });
    }
  }

  Future<void> _submitTotp() async {
    if (_busy || !_mfa) return;
    final code = _totp.text;
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() => _error = 'Introduce los seis dígitos.');
      return;
    }
    final ticket = ++_requestEpoch;
    setState(() {
      _busy = true;
      _error = null;
    });
    _totp.clear();
    try {
      await widget.gateway.verifyTotp(code);
      if (!mounted || ticket != _requestEpoch) return;
      setState(() => _busy = false);
      widget.onAuthenticated();
    } catch (_) {
      if (!mounted || ticket != _requestEpoch) return;
      setState(() {
        _busy = false;
        _error = 'No se ha podido verificar el código.';
      });
    }
  }

  Future<void> _backToPassword() async {
    // Invalidate callbacks before async challenge cancellation.
    _requestEpoch++;
    _totp.clear();
    setState(() {
      _mfa = false;
      _busy = false;
      _error = null;
    });
    try {
      await widget.gateway.abandonChallenge();
    } catch (_) {
      // No local session was activated. An unexpired server challenge is
      // useless without its opaque random secret and a verified TOTP.
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('VENCIRA')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(Icons.verified_user_outlined,
                        color: scheme.primary, size: 46),
                    const SizedBox(height: 20),
                    Text(
                      _mfa ? 'Verificación en dos pasos' : 'Acceso seguro',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _mfa
                          ? 'Introduce el código de tu aplicación de autenticación.'
                          : 'Accede a tu espacio de trabajo.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),
                    if (!_mfa) ...[
                      TextField(
                        key: const Key('native-login-username'),
                        controller: _username,
                        enabled: !_busy,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.username],
                        decoration: const InputDecoration(
                          labelText: 'Usuario',
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => _submitPassword(),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        key: const Key('native-login-password'),
                        controller: _password,
                        enabled: !_busy,
                        obscureText: true,
                        enableSuggestions: false,
                        autocorrect: false,
                        autofillHints: const [AutofillHints.password],
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(
                          labelText: 'Contraseña',
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => _submitPassword(),
                      ),
                    ] else ...[
                      TextField(
                        key: const Key('native-login-totp'),
                        controller: _totp,
                        enabled: !_busy,
                        obscureText: true,
                        enableSuggestions: false,
                        autocorrect: false,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Código de seis dígitos',
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => _submitTotp(),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        key: const Key('native-login-error'),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: scheme.error),
                      ),
                    ],
                    const SizedBox(height: 22),
                    FilledButton(
                      key: const Key('native-login-submit'),
                      onPressed: _busy ? null : (_mfa ? _submitTotp : _submitPassword),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: _busy
                            ? const SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(_mfa ? 'Verificar código' : 'Entrar'),
                      ),
                    ),
                    if (_mfa) ...[
                      const SizedBox(height: 8),
                      TextButton(
                        key: const Key('native-login-back'),
                        onPressed: _backToPassword,
                        child: const Text('Volver al acceso'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
