import 'package:flutter/material.dart';

import '../models/business_profile.dart';
import '../theme/app_theme.dart';
import '../widgets/admin/ds_states.dart';

/// Contenido de la sección "Reseñas" embebido en [BusinessShell] — sin
/// Scaffold/AppBar propio, igual que las páginas del panel admin.
class BusinessReviewsContent extends StatelessWidget {
  final BusinessProfile business;

  const BusinessReviewsContent({super.key, required this.business});

  static const _distribution = [72, 18, 6, 3, 1];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Reseñas de clientes', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 20)),
                const SizedBox(height: 16),
                if (!business.verified)
                  const DsEmptyState(
                    icon: Icons.forum_outlined,
                    title: 'Aún no hay reseñas',
                    subtitle: 'Este negocio todavía no está activo en el mapa.',
                  )
                else ...[
                  _buildSummary(),
                  const SizedBox(height: 20),
                  ...businessReviews.map((r) => _buildReview(r)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummary() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.panelNavySoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.overlay(0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            children: [
              Text('${business.rating}', style: TextStyle(color: AppColors.textPrimary, fontSize: 36, fontWeight: FontWeight.w700)),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  5,
                  (i) => Icon(Icons.star, size: 13, color: i < business.rating.round() ? Colors.amber : AppColors.overlay(0.15)),
                ),
              ),
              const SizedBox(height: 4),
              Text('${business.totalReviews} reseñas', style: TextStyle(color: AppColors.slate400, fontSize: 11)),
            ],
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              children: List.generate(5, (i) {
                final stars = 5 - i;
                final pct = _distribution[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Text('$stars', style: TextStyle(color: AppColors.slate400, fontSize: 11)),
                      const SizedBox(width: 4),
                      const Icon(Icons.star, size: 10, color: Colors.amber),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: pct / 100,
                            minHeight: 6,
                            backgroundColor: AppColors.overlay(0.08),
                            valueColor: const AlwaysStoppedAnimation(Colors.amber),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 28,
                        child: Text('$pct%', textAlign: TextAlign.right, style: TextStyle(color: AppColors.slate400, fontSize: 11)),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReview(BusinessReview r) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.panelNavySoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.overlay(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.brandTeal.withValues(alpha: 0.15),
                    child: Text(r.initials, style: TextStyle(color: AppColors.brandTeal, fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.author, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                      Text(r.dateLabel, style: TextStyle(color: AppColors.slate500, fontSize: 11)),
                    ],
                  ),
                ],
              ),
              Row(
                children: List.generate(5, (i) => Icon(Icons.star, size: 13, color: i < r.rating ? Colors.amber : AppColors.overlay(0.15))),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(r.text, style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4)),
        ],
      ),
    );
  }
}
