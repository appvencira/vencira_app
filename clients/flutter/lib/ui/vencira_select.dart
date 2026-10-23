import 'package:flutter/material.dart';

/// Opción sin dependencias de los widgets estándar de menú desplegable.
/// Se utiliza en los filtros y en el editor para dar el mismo acabado visual.
class VenciraOption<T> {
  const VenciraOption({required this.value, required this.label, this.icon});
  final T value;
  final String label;
  final IconData? icon;
}

/// Campo selectivo compacto que abre una hoja de opciones desplazable.
/// Para móvil y escritorio utiliza el mismo menú; conserva foco, accesibilidad
/// y la elección explícita sin guardar estados de negocio internamente.
class VenciraSelect<T> extends StatelessWidget {
  const VenciraSelect({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.prefixIcon,
  });

  final String label;
  final T? value;
  final List<VenciraOption<T>> options;
  final ValueChanged<T>? onChanged;
  final IconData? prefixIcon;

  Future<void> _showChoices(BuildContext context) async {
    if (onChanged == null || options.isEmpty) return;
    final scheme = Theme.of(context).colorScheme;
    final chosen = await showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: scheme.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) => Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 520,
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.78,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 12, top: 4),
                child: Row(children: [
                  Expanded(child: Text(label,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ))),
                  IconButton(
                    tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                    onPressed: () => Navigator.pop(sheetContext),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ]),
              ),
              Flexible(child: ListView.separated(
                shrinkWrap: true,
                itemCount: options.length,
                separatorBuilder: (context, index) => const SizedBox(height: 5),
                itemBuilder: (rowContext, i) {
                  final option = options[i];
                  final selected = option.value == value;
                  return Semantics(
                    selected: selected,
                    button: true,
                    child: Material(
                      color: selected ? scheme.primaryContainer
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => Navigator.pop<T>(sheetContext, option.value),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 15, vertical: 13,
                          ),
                          child: Row(children: [
                            if (option.icon != null) ...[
                              Icon(option.icon, size: 20,
                                color: selected ? scheme.onPrimaryContainer
                                    : scheme.onSurfaceVariant),
                              const SizedBox(width: 12),
                            ],
                            Expanded(child: Text(option.label,
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(
                                color: selected ? scheme.onPrimaryContainer
                                    : scheme.onSurface,
                                fontWeight: selected
                                    ? FontWeight.w700 : FontWeight.w400,
                              ),
                              overflow: TextOverflow.ellipsis,
                            )),
                            if (selected)
                              Icon(Icons.check_circle_rounded,
                                color: scheme.primary, size: 22),
                          ]),
                        ),
                      ),
                    ),
                  );
                },
              )),
            ]),
          ),
        ),
      ),
    );
    if (chosen != null && context.mounted) onChanged?.call(chosen);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    VenciraOption<T>? current;
    for (final option in options) {
      if (option.value == value) {
        current = option;
        break;
      }
    }
    final enabled = onChanged != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: '$label: ${current?.label ?? ""}',
      child: Material(
        color: enabled ? scheme.surfaceContainer : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: enabled ? () => _showChoices(context) : null,
          borderRadius: BorderRadius.circular(14),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 62),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 15, vertical: 10),
              child: Row(children: [
                if (prefixIcon != null) ...[
                  Icon(prefixIcon, size: 19, color: scheme.primary),
                  const SizedBox(width: 12),
                ],
                Expanded(child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 3),
                    Text(current?.label ?? '',
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: enabled ? scheme.onSurface
                            : scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600)),
                  ],
                )),
                const SizedBox(width: 9),
                Icon(Icons.keyboard_arrow_down_rounded,
                  color: scheme.onSurfaceVariant),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Identificador cromático accesible y coherente entre tarjetas y fichas.
/// Ámbar: pendiente, petróleo: contactado, verde: cerrado.
class VenciraStatusBadge extends StatelessWidget {
  const VenciraStatusBadge({
    super.key, required this.status, required this.label,
  });
  final String status;
  final String label;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final (background, foreground, icon) = switch (status) {
      'pending' => (
        dark ? const Color(0xFF47371F) : const Color(0xFFFFEBC7),
        dark ? const Color(0xFFFFD891) : const Color(0xFF815000),
        Icons.schedule_rounded,
      ),
      'contacted' => (
        dark ? const Color(0xFF183B48) : const Color(0xFFDBF2F8),
        dark ? const Color(0xFFA0DDEC) : const Color(0xFF135D71),
        Icons.forum_outlined,
      ),
      'closed' => (
        dark ? const Color(0xFF203F32) : const Color(0xFFDDF4E5),
        dark ? const Color(0xFFA8E4BD) : const Color(0xFF246B43),
        Icons.check_circle_outline_rounded,
      ),
      _ => (
        Theme.of(context).colorScheme.surfaceContainer,
        Theme.of(context).colorScheme.onSurfaceVariant,
        Icons.label_outline_rounded,
      ),
    };

    return Semantics(
      label: label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: foreground, size: 15),
          const SizedBox(width: 6),
          Flexible(child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: foreground,
            ),
          )),
        ]),
      ),
    );
  }
}
