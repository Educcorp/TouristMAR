import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/breakpoints.dart';
import '../theme/theme_controller.dart';
import '../widgets/hero_panel.dart';
import '../widgets/login_form.dart';
import '../widgets/themed_builder.dart';

class LoginPage extends StatelessWidget {
  final String? initialError;
  final bool startInBusinessRegister;

  const LoginPage({super.key, this.initialError, this.startInBusinessRegister = false});

  @override
  Widget build(BuildContext context) {
    return ThemedBuilder(builder: (context) => _buildScaffold());
  }

  Widget _buildScaffold() {
    return Scaffold(
      backgroundColor: AppColors.panelNavy,
      body: Stack(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = Breakpoints.isExpanded(constraints.maxWidth);

              if (!isWide) {
                return LoginForm(initialError: initialError, startInBusinessRegister: startInBusinessRegister);
              }

              return Row(
                children: [
                  const Expanded(flex: 58, child: HeroPanel()),
                  Expanded(flex: 42, child: LoginForm(initialError: initialError, startInBusinessRegister: startInBusinessRegister)),
                ],
              );
            },
          ),
          Positioned(
            top: 16,
            right: 16,
            child: SafeArea(
              child: IconButton(
                onPressed: ThemeController.toggle,
                tooltip: ThemeController.isDark ? 'Cambiar a modo claro' : 'Cambiar a modo oscuro',
                icon: Icon(
                  ThemeController.isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                  color: AppColors.slate300,
                ),
                style: IconButton.styleFrom(backgroundColor: AppColors.overlay(0.05)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
