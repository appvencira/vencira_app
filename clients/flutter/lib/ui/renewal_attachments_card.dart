import 'package:flutter/material.dart';

/// C-FICHA: visual section without upload/download actions until authorized.
class VenciraRenewalAttachmentsCard extends StatelessWidget {
  const VenciraRenewalAttachmentsCard({super.key, required this.locale});
  final String locale;

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
