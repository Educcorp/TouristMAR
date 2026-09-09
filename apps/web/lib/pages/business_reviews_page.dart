import 'package:flutter/material.dart';

import '../models/business_profile.dart';
import '../theme/app_theme.dart';
import '../widgets/app_shell.dart';

class BusinessReviewsPage extends StatelessWidget {
  final BusinessProfile business;

  const BusinessReviewsPage({super.key, required this.business});

  static const _distribution = [72, 18, 6, 3, 1];

  @override
  Widget build(BuildContext context) {
    return AppShell(
      accentColor: AppColors.businessOrange,
      badgeText: 'EMPRESA',
      avatarIcon: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: AppColors.businessOrange.withOpacity(0.12),
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.businessOrange.withOpacity(0.4)),
        ),
        child: const Icon(Icons.apartment, size: 16, color: AppColors.businessOrange),
      ),
      drawerIdentity: BusinessIdentityCard(business: business),
      navItems: businessNavItems(context, business: business),
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back, size: 15, color: AppColors.slate400),
                        label: const Text('Volver', style: TextStyle(color: AppColors.slate400, fontSize: 13)),
                      ),
                      const SizedBox(width: 8),
                      Text('Reseñas de clientes', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 20)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSummary(),
                  const SizedBox(height: 20),
                  ...businessReviews.map((r) => _buildReview(r)),
                ],
              ),
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
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            children: [
              Text('${business.rating}', style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w700)),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  5,
                  (i) => Icon(Icons.star, size: 13, color: i < business.rating.round() ? Colors.amber : Colors.white.withOpacity(0.15)),
                ),
              ),
              const SizedBox(height: 4),
              Text('${business.totalReviews} reseñas', style: const TextStyle(color: AppColors.slate400, fontSize: 11)),
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
                      Text('$stars', style: const TextStyle(color: AppColors.slate400, fontSize: 11)),
                      const SizedBox(width: 4),
                      const Icon(Icons.star, size: 10, color: Colors.amber),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: pct / 100,
                            minHeight: 6,
                            backgroundColor: Colors.white.withOpacity(0.08),
                            valueColor: const AlwaysStoppedAnimation(Colors.amber),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 28,
                        child: Text('$pct%', textAlign: TextAlign.right, style: const TextStyle(color: AppColors.slate400, fontSize: 11)),
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
        border: Border.all(color: Colors.white.withOpacity(0.08)),
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
                    backgroundColor: AppColors.brandTeal.withOpacity(0.15),
                    child: Text(r.initials, style: const TextStyle(color: AppColors.brandTeal, fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.author, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                      Text(r.dateLabel, style: const TextStyle(color: AppColors.slate500, fontSize: 11)),
                    ],
                  ),
                ],
              ),
              Row(
                children: List.generate(5, (i) => Icon(Icons.star, size: 13, color: i < r.rating ? Colors.amber : Colors.white.withOpacity(0.15))),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(r.text, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4)),
        ],
      ),
    );
  }
}
