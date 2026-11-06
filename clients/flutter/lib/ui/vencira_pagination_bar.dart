import 'package:flutter/material.dart';

/// Barra de paginación común: centro geométrico estable a cualquier ancho.
/// Conservar igual espacio para ambos botones incluso cuando estén inactivos.
class VenciraPaginationBar extends StatelessWidget {
  const VenciraPaginationBar({
    super.key,
    required this.pageLabel,
    required this.previousLabel,
    required this.nextLabel,
    required this.onPrevious,
    required this.onNext,
  });

  final String pageLabel, previousLabel, nextLabel;
  final VoidCallback? onPrevious, onNext;

  Widget _button({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    required bool isPrevious,
    required bool compact,
  }) {
    return OutlinedButton(
      key: ValueKey(isPrevious ? 'pagination-previous' : 'pagination-next'),
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 46),
        padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 10),
        visualDensity: VisualDensity.compact,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isPrevious) Icon(icon, size: 17),
          if (isPrevious) const SizedBox(width: 4),
          Flexible(child: Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center)),
          if (!isPrevious) const SizedBox(width: 4),
          if (!isPrevious) Icon(icon, size: 17),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final compact = constraints.maxWidth < 380;
      return Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(child: _button(
              icon: Icons.chevron_left,
              label: previousLabel,
              onPressed: onPrevious,
              isPrevious: true,
              compact: compact)),
            const SizedBox(width: 8),
            Text(pageLabel,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(width: 8),
            Expanded(child: _button(
              icon: Icons.chevron_right,
              label: nextLabel,
              onPressed: onNext,
              isPrevious: false,
              compact: compact)),
          ],
        ),
      ));
    });
  }
}
