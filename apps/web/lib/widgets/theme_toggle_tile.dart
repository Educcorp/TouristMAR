import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';

/// Fila para el drawer de navegación que alterna modo claro/oscuro. Misma
/// pinta que el resto de las opciones del drawer (ver `_NavDrawer` en
/// `app_shell.dart` y `_AdminNavDrawer` en `admin_shell.dart`).
class ThemeToggleTile extends StatelessWidget {
  // Sin constructor `const`: build() lee `ThemeController.isDark`, un valor
  // externo mutable que no pasa por el constructor. Si esto fuera `const`,
  // Dart canonicalizaría la instancia y Flutter la trataría como "nunca
  // cambia" — se saltaría el rebuild entero al alternar el tema (el switch y
  // la etiqueta se quedarían congelados en el valor del primer render, que
  // es justo el bug que se reportó).
  ThemeToggleTile({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeController.isDark;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: ThemeController.toggle,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                  size: 18, color: AppColors.slate300),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isDark ? 'Modo oscuro' : 'Modo claro',
                  style: TextStyle(color: AppColors.overlay(0.85), fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
              Switch.adaptive(
                value: isDark,
                onChanged: (_) => ThemeController.toggle(),
                activeColor: AppColors.brandTeal,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
