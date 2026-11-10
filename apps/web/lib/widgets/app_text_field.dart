import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AppTextField extends StatelessWidget {
  final String label;
  final IconData icon;
  final TextEditingController controller;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? hintText;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final Key? fieldKey;
  final Color? accentColor;
  final int maxLines;

  // Sin `const` a propósito: build() lee AppColors (depende de
  // ThemeController); una instancia const no se reconstruiría al cambiar el
  // tema y se quedaría con los colores viejos.
  // ignore: prefer_const_constructors_in_immutables
  AppTextField({
    super.key,
    required this.label,
    required this.icon,
    required this.controller,
    this.obscureText = false,
    this.keyboardType,
    this.hintText,
    this.suffixIcon,
    this.validator,
    this.fieldKey,
    this.accentColor,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.label),
        const SizedBox(height: 6),
        TextFormField(
          key: fieldKey,
          controller: controller,
          obscureText: obscureText,
          maxLines: obscureText ? 1 : maxLines,
          keyboardType: keyboardType,
          validator: validator,
          // 16 px: legible al sol y evita que el navegador del celular haga
          // zoom al enfocar el campo.
          style: TextStyle(color: AppColors.textPrimary, fontSize: 16),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(color: AppColors.slate500, fontSize: 16),
            prefixIcon: Icon(icon, size: 20, color: AppColors.slate400),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: AppColors.panelNavySoft,
            contentPadding: const EdgeInsets.fromLTRB(0, 14, 12, 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.button),
              borderSide: BorderSide(color: AppColors.borderSubtle),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.button),
              borderSide: BorderSide(color: AppColors.borderSubtle),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.button),
              borderSide: BorderSide(color: accentColor ?? AppColors.tinta, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.button),
              borderSide: BorderSide(color: AppColors.errorRed, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.button),
              borderSide: BorderSide(color: AppColors.errorRed, width: 2),
            ),
            errorStyle: TextStyle(color: AppColors.errorRed, fontSize: 13),
          ),
        ),
      ],
    );
  }
}
