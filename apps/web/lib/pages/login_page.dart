import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/breakpoints.dart';
import '../widgets/hero_panel.dart';
import '../widgets/login_form.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.panelNavy,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = Breakpoints.isExpanded(constraints.maxWidth);

          if (!isWide) {
            return LoginForm();
          }

          return Row(
            children: [
              const Expanded(flex: 58, child: HeroPanel()),
              Expanded(flex: 42, child: LoginForm()),
            ],
          );
        },
      ),
    );
  }
}
