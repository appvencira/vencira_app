import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// The Android APK has no native authentication contract yet.
/// Open the existing HTTPS session in the system browser rather than silently
/// making unauthenticated HTTP requests from an isolated native client.
class AndroidWebAccessScreen extends StatelessWidget {
  const AndroidWebAccessScreen({super.key, this.statusMessage});

  /// Optional fail-closed native startup notice, never an auth result.
  final String? statusMessage;

  static final Uri previewUri = Uri.parse('https://dev.vencira.es/');

  Future<void> _openWeb(BuildContext context) async {
    try {
      final launched = await launchUrl(
        previewUri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir el navegador.')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir el navegador.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('VENCIRA')),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.shield_outlined, size: 44),
                  const SizedBox(height: 20),
                  Text('Acceso seguro a VENCIRA',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  const Text(
                    'El acceso autenticado está disponible actualmente en '
                    'la versión web. La aplicación Android nativa aún no '
                    'admite inicio de sesión seguro.',
                    textAlign: TextAlign.center,
                  ),
                  if (statusMessage != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      statusMessage!,
                      key: const Key('native-startup-status'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => _openWeb(context),
                    icon: const Icon(Icons.open_in_browser),
                    label: const Text('Abrir VENCIRA en el navegador'),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Versión de desarrollo. No introducir información real '
                    'de clientes.',
                    textAlign: TextAlign.center,
                  ),
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
