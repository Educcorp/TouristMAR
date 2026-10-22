import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum AvisoTipo { exito, error, info }

/// Barra flotante de aviso (éxito, error o informativo): bordes redondeados,
/// icono y franja del color del tipo, se va sola a los pocos segundos y se
/// puede cerrar antes con la X. Se usa en lugar de un `SnackBar` suelto para
/// que todos los mensajes del sistema se vean igual.
///
/// Si no se indica [tipo], se deduce del texto ("No se pudo…" = error,
/// "…guardado" = éxito); en caso de duda queda como informativo.
SnackBar aviso(String texto, {AvisoTipo? tipo, SnackBarAction? accion}) {
  final t = tipo ?? _deducirTipo(texto);
  final (icono, color) = switch (t) {
    AvisoTipo.exito => (Icons.check_circle_rounded, AppColors.emerald),
    AvisoTipo.error => (Icons.error_rounded, AppColors.rojoTexto),
    AvisoTipo.info => (Icons.info_rounded, AppColors.azulTexto),
  };
  return SnackBar(
    duration: Duration(seconds: t == AvisoTipo.error ? 6 : 4),
    showCloseIcon: true,
    closeIconColor: AppColors.slate400,
    backgroundColor: AppColors.cubierta,
    elevation: 6,
    padding: EdgeInsets.zero,
    action: accion,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: color.withValues(alpha: 0.45)),
    ),
    content: IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 5,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
            ),
          ),
          const SizedBox(width: 12),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Icon(icono, color: color, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(texto, style: TextStyle(color: AppColors.tinta, fontSize: 14.5, height: 1.3)),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Atajo: `mostrarAviso(context, 'Guardado')`.
void mostrarAviso(BuildContext context, String texto, {AvisoTipo? tipo}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(aviso(texto, tipo: tipo));
}

final _pistasError = RegExp(
  r'^no |no se pud|no pudimos|error|inválid|falló|fallo|necesita|todavía no|aún no|sin conexión|no está|no tienes|elige|completa',
  caseSensitive: false,
);
final _pistasExito = RegExp(
  r'guardad|actualizad|enviad|aprobad|agregad|cread|eliminad|borrad|publicad|gracias|listo|marcad|quitad|subid|rechazad|copiad',
  caseSensitive: false,
);

AvisoTipo _deducirTipo(String texto) {
  if (_pistasError.hasMatch(texto)) return AvisoTipo.error;
  if (_pistasExito.hasMatch(texto)) return AvisoTipo.exito;
  return AvisoTipo.info;
}
