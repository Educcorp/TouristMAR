import 'package:flutter/material.dart';

import '../models/business_profile.dart';
import '../theme/app_theme.dart';
import '../theme/breakpoints.dart';
import '../widgets/app_shell.dart';
import '../widgets/cover_image.dart';
import 'business_edit_page.dart';
import 'business_reviews_page.dart';

class BusinessDashboardPage extends StatefulWidget {
  final BusinessProfile business;

  const BusinessDashboardPage({super.key, required this.business});

  @override
  State<BusinessDashboardPage> createState() => _BusinessDashboardPageState();
}

class _BusinessDashboardPageState extends State<BusinessDashboardPage> {
  Future<void> _openEdit() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => BusinessEditPage(business: widget.business)),
    );
    if (changed == true && mounted) setState(() {});
  }

  void _openReviews() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => BusinessReviewsPage(business: widget.business)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final business = widget.business;

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
            constraints: const BoxConstraints(maxWidth: 960),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHero(business),
                  const SizedBox(height: 20),
                  _buildStatsGrid(business),
                  const SizedBox(height: 28),
                  const Text(
                    'Gestionar negocio',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  _buildManageGrid(),
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Reseñas recientes',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      GestureDetector(
                        onTap: _openReviews,
                        child: const Text(
                          'Ver todas',
                          style: TextStyle(color: AppColors.businessOrange, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...businessReviews.take(2).map((r) => _RecentReviewTile(review: r)),
                  const SizedBox(height: 20),
                  _buildAlertBanner(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHero(BusinessProfile business) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: 170,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CoverImage(source: business.coverImage),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomLeft,
                  end: Alignment.topRight,
                  colors: [AppColors.panelNavy.withOpacity(0.92), AppColors.panelNavy.withOpacity(0.4)],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      const Text(
                        'PANEL DE NEGOCIO',
                        style: TextStyle(
                            color: AppColors.businessOrange, fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 2),
                      ),
                      if (business.verified) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.check_circle, size: 12, color: AppColors.brandTeal),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(business.businessName, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 22)),
                  const SizedBox(height: 2),
                  Text(business.category, style: const TextStyle(color: AppColors.slate300, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid(BusinessProfile business) {
    final stats = [
      (Icons.people_outline, '${business.monthlyVisits}', 'Visitas este mes', AppColors.brandTeal),
      (Icons.star_outline, '${business.rating}★', 'Calificación promedio', Colors.amber),
      (Icons.forum_outlined, '${business.newReviews}', 'Reseñas nuevas', AppColors.businessOrange),
      (Icons.thumb_up_outlined, '${business.favorites}', 'Marcado favorito', Colors.greenAccent),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = Breakpoints.isCompact(constraints.maxWidth) ? 2 : 4;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.3,
          children: stats.map((s) {
            final (icon, value, label, color) = s;
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: color.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 16, color: color),
                  const SizedBox(height: 8),
                  Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(label, style: const TextStyle(color: AppColors.slate400, fontSize: 11)),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildManageGrid() {
    final actions = [
      (Icons.edit_outlined, 'Editar información', AppColors.brandTeal, _openEdit),
      (Icons.image_outlined, 'Gestionar fotos', AppColors.businessOrange, _openEdit),
      (Icons.forum_outlined, 'Ver reseñas', Colors.amber, _openReviews),
      (Icons.trending_up, 'Estadísticas', Colors.greenAccent, () {}),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = Breakpoints.isCompact(constraints.maxWidth) ? 2 : 4;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.05,
          children: actions.map((a) {
            final (icon, label, color, onTap) = a;
            return Material(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
                        child: Icon(icon, color: color, size: 18),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildAlertBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.businessOrange.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.businessOrange.withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 16, color: AppColors.businessOrange),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Completa tu perfil de negocio',
                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Agrega horarios detallados y al menos 5 fotos para aparecer destacado en el mapa.',
                  style: TextStyle(color: AppColors.slate400, fontSize: 12),
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: _openEdit,
                  child: const Text(
                    'Completar ahora →',
                    style: TextStyle(color: AppColors.businessOrange, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentReviewTile extends StatelessWidget {
  final BusinessReview review;

  const _RecentReviewTile({required this.review});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.brandTeal.withOpacity(0.15),
            child: Text(review.initials, style: const TextStyle(color: AppColors.brandTeal, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(review.author, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                    Row(
                      children: [
                        Row(
                          children: List.generate(
                            5,
                            (i) => Icon(Icons.star, size: 11, color: i < review.rating ? Colors.amber : Colors.white.withOpacity(0.15)),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(review.dateLabel, style: const TextStyle(color: AppColors.slate500, fontSize: 10)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  review.text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
