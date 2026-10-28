import 'package:flutter/material.dart';
import '../api/vencira_api.dart';

/// C-FICHA: visual section without upload/download actions until authorized.
class VenciraRenewalAttachmentsCard extends StatelessWidget {
  const VenciraRenewalAttachmentsCard({super.key, required this.locale,
      this.api, this.workspaceId, this.renewalId});
  final String locale;
  final VenciraApi? api;
  final String? workspaceId;
  final String? renewalId;

  @override
  Widget build(BuildContext context) {
    final ca = locale == 'ca';
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
          Text(ca
            ? 'Arxius PDF i imatges vinculats a aquesta pòlissa.'
            : 'Archivos PDF e imágenes vinculados a esta póliza.',
            style: theme.textTheme.bodyMedium),
          const SizedBox(height: 10),
          if (api != null && workspaceId != null && renewalId != null)
            FutureBuilder<Map<String, dynamic>>(
              future: api!.fetchAttachmentCapabilities(workspaceId!, renewalId!),
              builder: (context, snapshot) {
                // Even if backend flags change unexpectedly, this release
                // has no download or upload actions.
                final ready = snapshot.hasData &&
                  snapshot.data!["upload"] == false &&
                  snapshot.data!["download"] == false &&
                  snapshot.data!["delete"] == false;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(ready
                    ? (ca ? "Accés restringit per seguretat" : "Acceso restringido por seguridad")
                    : (ca ? "Documents no disponibles" : "Documentos no disponibles"),
                    style: theme.textTheme.labelSmall),
                );
              },
            ),
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
