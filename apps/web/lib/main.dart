import 'package:flutter/material.dart';

import 'pages/login_page.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const TouristMarApp());
}

class TouristMarApp extends StatelessWidget {
  const TouristMarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TourisMAR — Iniciar sesión',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const LoginPage(),
    );
  }
}
