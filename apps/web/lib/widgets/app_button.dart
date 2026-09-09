import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum AppButtonVariant { primary, google, ghost }

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

    return SizedBox(
      width: double.infinity,
      child: Material(
        color: colors.background,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: colors.border,
            ),
            child: DefaultTextStyle.merge(
              style: TextStyle(color: colors.foreground, fontWeight: FontWeight.w500, fontSize: 14),
              child: IconTheme.merge(
                data: IconThemeData(color: colors.foreground, size: 18),
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
          background: disabled ? AppColors.brandTeal.withOpacity(0.5) : AppColors.brandTeal,
          foreground: AppColors.panelNavy,
        );
      case AppButtonVariant.google:
        return _ButtonColors(
          background: Colors.white,
          foreground: const Color(0xFF1E293B),
        );
      case AppButtonVariant.ghost:
        return _ButtonColors(
          background: Colors.white.withOpacity(0.05),
          foreground: Colors.white,
          border: Border.all(color: Colors.white.withOpacity(0.1)),
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
