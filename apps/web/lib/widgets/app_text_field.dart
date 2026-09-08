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

  const AppTextField({
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
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.slate300, fontSize: 14)),
        const SizedBox(height: 8),
        TextFormField(
          key: fieldKey,
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          validator: validator,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(color: AppColors.slate500),
            prefixIcon: Icon(icon, size: 18, color: AppColors.slate500),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: AppColors.panelNavySoft,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.brandTeal),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.errorRed),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.errorRed),
            ),
          ),
        ),
      ],
    );
  }
}
