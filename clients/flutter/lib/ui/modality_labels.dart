import 'package:flutter/material.dart';
import '../api/vencira_api.dart';
import '../l10n/app_localizations.dart';

String modalityCaption(BuildContext context, VenciraModalityOption option) {
  if (!option.builtin || option.label != optionDefaultCaption(option.code)) {
    return option.label;
  }
  final t = AppLocalizations.of(context)!;
  return switch (option.code) {
    'autos' => t.modAutos,
    'motos' => t.modMotos,
    'patinetes' => t.modPatinetes,
    'hogar' => t.modHogar,
    'comercio' => t.modComercio,
    'decesos' => t.modDecesos,
    'salud' => t.modSalud,
    'vida' => t.modVida,
    'accidentes' => t.modAccidentes,
    'rc' => t.modRc,
    'comunidades' => t.modComunidades,
    'otros' => t.modOtros,
    _ => option.label,
  };
}

String optionDefaultCaption(String code) {
  for (final item in VenciraModalityOption.defaults) {
    if (item.code == code) return item.label;
  }
  return '';
}
