import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum AppButtonVariant { primary, google, ghost }

/// Botón de ancho completo de los formularios (login, registro, guardar).
/// 48 px de alto como mínimo: se usa con el pulgar y al sol.
class AppButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final Widget child;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const AppButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.variant = AppButtonVariant.primary,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    final base = _colorsFor(variant, disabled);
    final colors = _ButtonColors(
      background: backgroundColor ?? base.background,
      foreground: foregroundColor ?? base.foreground,
      border: base.border,
    );
    final radio = BorderRadius.circular(AppRadius.button);

    return SizedBox(
      width: double.infinity,
      child: Material(
        color: colors.background,
        borderRadius: radio,
        child: InkWell(
          onTap: onPressed,
          borderRadius: radio,
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(borderRadius: radio, border: colors.border),
            child: DefaultTextStyle.merge(
              style: AppTypography.boton(color: colors.foreground),
              child: IconTheme.merge(
                data: IconThemeData(color: colors.foreground, size: 20),
                child: Center(child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }

  _ButtonColors _colorsFor(AppButtonVariant variant, bool disabled) {
    switch (variant) {
      case AppButtonVariant.primary:
        return _ButtonColors(
          background: disabled ? AppColors.surfaceAlt : AppColors.brandTeal,
          foreground: disabled ? AppColors.slate500 : AppColors.panelNavy,
        );
      case AppButtonVariant.google:
        return _ButtonColors(
          background: AppColors.cubierta,
          foreground: AppColors.tinta,
          border: Border.all(color: AppColors.borderSubtle),
        );
      case AppButtonVariant.ghost:
        return _ButtonColors(
          background: Colors.transparent,
          foreground: AppColors.tinta,
          border: Border.all(color: AppColors.borderSubtle, width: 1.5),
        );
    }
  }
}

class _ButtonColors {
  final Color background;
  final Color foreground;
  final Border? border;

  _ButtonColors({required this.background, required this.foreground, this.border});
}
