import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class RegisterPlaceBanner extends StatelessWidget {
  final VoidCallback? onTap;

  const RegisterPlaceBanner({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.overlay(0.05),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap ?? () {},
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.overlay(0.1)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: AppColors.brandTeal.withValues(alpha: 0.15), shape: BoxShape.circle),
                child: Icon(Icons.location_on_outlined, size: 18, color: AppColors.brandTeal),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '¿Te gustaría registrar un lugar nuevo?',
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    Text(
                      'Propón tu negocio o sitio turístico',
                      style: TextStyle(color: AppColors.slate400, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: AppColors.slate400),
            ],
          ),
        ),
      ),
    );
  }
}
