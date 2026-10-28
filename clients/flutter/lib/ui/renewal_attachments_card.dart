import 'package:flutter/material.dart';
import '../api/vencira_api.dart';

/// Read-only documents panel. No operation can fetch or expose file content.
class VenciraRenewalAttachmentsCard extends StatefulWidget {
  const VenciraRenewalAttachmentsCard({super.key, required this.locale,
    this.api, this.workspaceId, this.renewalId});
  final String locale;
  final VenciraApi? api;
  final String? workspaceId;
  final String? renewalId;

  @override
  State<VenciraRenewalAttachmentsCard> createState() => _AttachmentCardState();
}

class _AttachmentCardState extends State<VenciraRenewalAttachmentsCard> {
  Future<Map<String, dynamic>>? _manifest;

  void _retry() {
    setState(_load);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant VenciraRenewalAttachmentsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.api != widget.api ||
        oldWidget.workspaceId != widget.workspaceId ||
        oldWidget.renewalId != widget.renewalId) {
      _load();
    }
  }

  void _load() {
    final api = widget.api;
    final workspace = widget.workspaceId;
    final renewal = widget.renewalId;
    _manifest = api != null && workspace != null && renewal != null
      ? api.fetchAttachmentManifest(workspace, renewal) : null;
  }

  @override
  Widget build(BuildContext context) {
    final ca = widget.locale == 'ca';
    final theme = Theme.of(context);
    return Card.outlined(
      key: const ValueKey('renewal-attachments-locked'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(Icons.folder_copy_outlined,
              color: theme.colorScheme.primary, size: 23),
            const SizedBox(width: 12),
            Expanded(child: Text(ca ? 'Documents i fotografies' : 'Documentos y fotografías',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
            const Icon(Icons.lock_outline, size: 18),
          ]),
          const SizedBox(height: 8),
          Text(ca ? 'Arxius PDF i imatges vinculats a aquesta pòlissa.'
            : 'Archivos PDF e imágenes vinculados a esta póliza.'),
          const SizedBox(height: 10),
          if (_manifest != null)
            FutureBuilder<Map<String, dynamic>>(
              future: _manifest,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                if (snapshot.hasError || !snapshot.hasData) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ca
                        ? 'No s’han pogut consultar els documents.'
                        : 'No se han podido consultar los documentos.',
                        style: theme.textTheme.bodySmall),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        key: const ValueKey('attachments-retry'),
                        onPressed: _retry,
                        icon: const Icon(Icons.refresh),
                        label: Text(ca ? 'Torna-ho a provar' : 'Reintentar'),
                      ),
                    ],
                  );
                }
                final data = snapshot.data!;
                final raw = data['results'];
                if (raw is! List) {
                  return Text(ca
                    ? 'Resposta de documents no vàlida'
                    : 'Respuesta de documentos no válida');
                }
                final entries = raw.whereType<Map<String, dynamic>>().toList();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (entries.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(ca
                          ? 'Encara no hi ha documents disponibles'
                          : 'Todavía no hay documentos disponibles',
                          style: theme.textTheme.bodySmall),
                      ),
                    for (final entry in entries)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.insert_drive_file_outlined),
                        title: Text(
                          entry['display_name'] is String
                            ? entry['display_name'] as String
                            : (ca ? 'Document' : 'Documento'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                        subtitle: Text(ca
                          ? 'Accés bloquejat'
                          : 'Acceso bloqueado'),
                        trailing: const Icon(Icons.lock_outline, size: 16),
                      ),
                  ],
                );
              },
            ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              const Icon(Icons.shield_outlined, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(ca
                ? 'Càrregues i descàrregues desactivades fins a acabar la revisió de seguretat.'
                : 'Cargas y descargas desactivadas hasta completar la revisión de seguridad.',
                style: theme.textTheme.bodySmall)),
            ]),
          ),
        ]),
      ),
    );
  }
}
