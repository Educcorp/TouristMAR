import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

enum DsButtonVariant { primary, secondary, ghost, danger }

enum DsButtonSize { sm, md }

/// Botón de ancho intrínseco (no se estira como [AppButton]) pensado para
/// acciones inline en tablas, toolbars y headers de card.
///
/// Un solo idioma con el resto del sistema: el primario es un relleno plano
/// (tinta por defecto), el secundario un contorno de tinta y el de peligro un
/// contorno rojo. Nada de rellenos tintados al 12 %: se leían como pastillas
/// de otro producto. Alto mínimo 40 (md) / 36 (sm) para que se puedan tocar.
class DsButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final DsButtonVariant variant;
  final DsButtonSize size;
  final Color? accent;

  const DsButton({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.variant = DsButtonVariant.secondary,
    this.size = DsButtonSize.md,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    final relleno = accent ?? AppColors.tinta;

    Color bg;
    Color fg;
    Color border;
    switch (variant) {
      case DsButtonVariant.primary:
        bg = relleno;
        fg = AppColors.casco;
        border = relleno;
        break;
      case DsButtonVariant.secondary:
        bg = AppColors.cubierta;
        fg = AppColors.tinta;
        border = AppColors.overlay(0.22);
        break;
      case DsButtonVariant.ghost:
        bg = Colors.transparent;
        fg = AppColors.slate300;
        border = Colors.transparent;
        break;
      case DsButtonVariant.danger:
        bg = AppColors.cubierta;
        fg = AppColors.errorRed;
        border = AppColors.errorRed.withValues(alpha: 0.45);
        break;
    }

    if (disabled) {
      bg = variant == DsButtonVariant.primary ? AppColors.surfaceAlt : bg;
      fg = AppColors.slate500;
      border = variant == DsButtonVariant.ghost ? Colors.transparent : AppColors.borderSubtle;
    }

    final chico = size == DsButtonSize.sm;
    final radio = BorderRadius.circular(AppRadius.button);

    return Material(
      color: Colors.transparent,
      borderRadius: radio,
      child: InkWell(
        onTap: onPressed,
        borderRadius: radio,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          // Alto fijo: la fila se centra en él (las etiquetas son cortas).
          height: chico ? 36 : 40,
          padding: EdgeInsets.symmetric(horizontal: chico ? 12 : 16),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: radio,
            border: Border.all(color: border, width: 1.25),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: chico ? 16 : 18, color: fg),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.boton(size: chico ? 14 : 15, color: fg),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
