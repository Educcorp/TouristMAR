import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

enum DsButtonVariant { primary, secondary, ghost, danger }

enum DsButtonSize { sm, md }

/// Botón de ancho intrínseco (no se estira como [AppButton]) pensado para
/// acciones inline en tablas, toolbars y headers de card.
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
    final color = accent ?? AppColors.adminViolet;
    final disabled = onPressed == null;

    Color bg;
    Color fg;
    Color border;
    switch (variant) {
      case DsButtonVariant.primary:
        bg = color;
        fg = AppColors.bgDeep;
        border = color;
        break;
      case DsButtonVariant.secondary:
        bg = color.withValues(alpha: 0.12);
        fg = color;
        border = color.withValues(alpha: 0.3);
        break;
      case DsButtonVariant.ghost:
        bg = Colors.transparent;
        fg = AppColors.slate300;
        border = AppColors.borderSubtle;
        break;
      case DsButtonVariant.danger:
        bg = AppColors.errorRed.withValues(alpha: 0.12);
        fg = AppColors.errorRed;
        border = AppColors.errorRed.withValues(alpha: 0.3);
        break;
    }

    if (disabled) {
      bg = bg.withValues(alpha: bg.a * 0.4);
      fg = fg.withValues(alpha: 0.4);
      border = border.withValues(alpha: 0.15);
    }

    final vPad = size == DsButtonSize.sm ? 8.0 : 11.0;
    final hPad = size == DsButtonSize.sm ? 12.0 : 16.0;
    final fontSize = size == DsButtonSize.sm ? 12.0 : 13.0;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.button),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppRadius.button),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppRadius.button),
            border: Border.all(color: border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: fg),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(color: fg, fontSize: fontSize, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
