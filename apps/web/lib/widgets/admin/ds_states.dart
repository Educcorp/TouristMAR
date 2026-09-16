import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'ds_button.dart';
import 'ds_icon_badge.dart';

class DsLoadingState extends StatelessWidget {
  final Color? accent;
  // Sin `const`: el color por default lee AppColors.adminViolet, que depende
  // de ThemeController — igual que AdminHelpPage/ThemeToggleTile, marcar
  // esto `const` congelaría el color si el tema cambia mientras se muestra.
  DsLoadingState({super.key, this.accent});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxxl),
      child: Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2.5, color: accent ?? AppColors.adminViolet),
        ),
      ),
    );
  }
}

class DsEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const DsEmptyState({super.key, required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxxl, horizontal: AppSpacing.xl),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DsIconBadgeCircle(icon: icon, color: AppColors.slate400, size: 52),
            const SizedBox(height: AppSpacing.lg),
            Text(title, style: AppTypography.h3, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.xs),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(subtitle, style: AppTypography.bodySmall, textAlign: TextAlign.center),
            ),
          ],
        ),
      ),
    );
  }
}

class DsErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const DsErrorState({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.errorRed.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.errorRed.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: AppColors.errorRed, size: 18),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(message, style: TextStyle(color: AppColors.errorRed, fontSize: 13)),
          ),
          if (onRetry != null) ...[
            const SizedBox(width: AppSpacing.md),
            DsButton(
              label: 'Reintentar',
              variant: DsButtonVariant.ghost,
              size: DsButtonSize.sm,
              onPressed: onRetry,
            ),
          ],
        ],
      ),
    );
  }
}
