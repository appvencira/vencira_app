import 'package:flutter/material.dart';
import '../api/vencira_api.dart';

/// Panel documental de solo lectura.
/// No expone contenido ni acciones de escritura.
class VenciraRenewalAttachmentsCard extends StatefulWidget {
  const VenciraRenewalAttachmentsCard({
    super.key,
    required this.locale,
    this.api,
    this.workspaceId,
    this.renewalId,
  });

  final String locale;
  final VenciraApi? api;
  final String? workspaceId;
  final String? renewalId;

  @override
  State<VenciraRenewalAttachmentsCard> createState() =>
      _AttachmentCardState();
}

class _AttachmentCardState
    extends State<VenciraRenewalAttachmentsCard> {
  Future<Map<String, dynamic>>? _manifest;

  bool get ca => widget.locale == 'ca';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(
    covariant VenciraRenewalAttachmentsCard oldWidget,
  ) {
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

    _manifest =
        api != null && workspace != null && renewal != null
            ? api.fetchAttachmentManifest(workspace, renewal)
            : null;
  }

  void _retry() {
    setState(_load);
  }

  String _stateLabel(String state) {
    switch (state) {
      case 'quarantined':
        return ca ? 'En quarantena' : 'En cuarentena';
      case 'clean':
        return ca ? 'Revisat · accés restringit'
            : 'Revisado · acceso restringido';
      case 'rejected':
        return ca ? 'Rebutjat' : 'Rechazado';
      default:
        return ca ? 'Estat no disponible'
            : 'Estado no disponible';
    }
  }

  IconData _stateIcon(String state) {
    switch (state) {
      case 'quarantined':
        return Icons.hourglass_top_rounded;
      case 'clean':
        return Icons.verified_outlined;
      case 'rejected':
        return Icons.block_outlined;
      default:
        return Icons.lock_outline;
    }
  }

  String _size(int bytes) {
    if (bytes >= 1048576) {
      return '${(bytes / 1048576).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '$bytes B';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Card.outlined(
      key: const ValueKey('renewal-attachments-locked'),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.folder_copy_outlined,
                    color: colors.onPrimaryContainer,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    ca ? 'Documents i fotografies'
                        : 'Documentos y fotografías',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: ca ? 'Accés restringit'
                      : 'Acceso restringido',
                  child: Icon(
                    Icons.lock_outline,
                    size: 19,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              ca
                  ? 'Arxius vinculats a aquesta pòlissa.'
                  : 'Archivos vinculados a esta póliza.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            if (_manifest != null)
              FutureBuilder<Map<String, dynamic>>(
                future: _manifest,
                builder: (context, snapshot) {
                  if (snapshot.connectionState !=
                      ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  if (snapshot.hasError || !snapshot.hasData) {
                    return Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          ca
                              ? 'No s’han pogut consultar els documents.'
                              : 'No se han podido consultar los documentos.',
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          key: const ValueKey('attachments-retry'),
                          onPressed: _retry,
                          icon: const Icon(Icons.refresh),
                          label: Text(
                            ca ? 'Torna-ho a provar' : 'Reintentar',
                          ),
                        ),
                      ],
                    );
                  }

                  final response = snapshot.data!;
                  final raw = response['results'];
                  final capabilities = response['capabilities'];

                  // Denegar cualquier manifiesto que anuncie
                  // operaciones documentales habilitadas.
                  if (raw is! List ||
                      capabilities is! Map ||
                      capabilities['upload'] != false ||
                      capabilities['download'] != false ||
                      capabilities['delete'] != false) {
                    return Text(
                      ca
                          ? 'Resposta de documents no vàlida'
                          : 'Respuesta de documentos no válida',
                    );
                  }

                  final entries =
                      raw.whereType<Map<String, dynamic>>().toList();

                  if (entries.isEmpty) {
                    return Padding(
                      padding:
                          const EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: Text(
                          ca
                              ? 'Encara no hi ha documents disponibles'
                              : 'Todavía no hay documentos disponibles',
                          style: theme.textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  return Column(
                    children: [
                      for (final entry in entries)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: colors.outlineVariant,
                              ),
                              borderRadius:
                                  BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _stateIcon(
                                    entry['state'] as String? ?? '',
                                  ),
                                  color: colors.onSurfaceVariant,
                                  size: 21,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        entry['display_name']
                                                as String? ??
                                            (ca
                                                ? 'Document'
                                                : 'Documento'),
                                        maxLines: 1,
                                        overflow:
                                            TextOverflow.ellipsis,
                                        style: theme
                                            .textTheme.bodyMedium
                                            ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${_stateLabel(entry['state'] as String? ?? '')}'
                                        ' · ${_size(entry['byte_size'] as int? ?? 0)}',
                                        maxLines: 2,
                                        style:
                                            theme.textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.lock_outline,
                                  size: 16,
                                  color: colors.onSurfaceVariant,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shield_outlined, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      ca
                          ? 'Càrregues i descàrregues desactivades fins a completar la revisió de seguretat.'
                          : 'Cargas y descargas desactivadas hasta completar la revisión de seguridad.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
