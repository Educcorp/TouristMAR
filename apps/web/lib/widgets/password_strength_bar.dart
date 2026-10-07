import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/password_strength.dart';

/// Barra de "qué tan fuerte es tu contraseña", solo para el formulario de
/// crear cuenta — se oculta mientras el campo está vacío.
class PasswordStrengthBar extends StatelessWidget {
  final String password;

  const PasswordStrengthBar({super.key, required this.password});

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) return const SizedBox.shrink();

    final result = evaluatePasswordStrength(password);
    final String label;
    final Color color;
    switch (result.level) {
      case PasswordStrengthLevel.muyDebil:
        label = 'Muy débil';
        color = AppColors.errorRed;
      case PasswordStrengthLevel.debil:
        label = 'Débil';
        color = AppColors.orange;
      case PasswordStrengthLevel.media:
        label = 'Media';
        color = AppColors.amber;
      case PasswordStrengthLevel.fuerte:
        label = 'Fuerte';
        color = AppColors.emerald;
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: result.score,
                    minHeight: 5,
                    backgroundColor: AppColors.overlay(0.08),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ),
          if (result.pendientes.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(result.pendientes.join(' · '), style: TextStyle(color: AppColors.slate500, fontSize: 11)),
          ],
        ],
      ),
    );
  }
}
