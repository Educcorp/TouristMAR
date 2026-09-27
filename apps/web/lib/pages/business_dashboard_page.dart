import 'package:flutter/material.dart';

import '../models/business_profile.dart';
import '../theme/app_theme.dart';
import '../theme/breakpoints.dart';
import '../widgets/cover_image.dart';
import 'business_edit_page.dart';
import 'business_gallery_page.dart';

/// Contenido de la sección "Dashboard" embebido en [BusinessShell] — sin
/// Scaffold/AppBar propio, igual que las páginas del panel admin.
class BusinessDashboardContent extends StatefulWidget {
  final BusinessProfile business;
  final VoidCallback onNegocioUpdated;
  final VoidCallback onOpenReviews;
  final VoidCallback onOpenExperiencias;

  const BusinessDashboardContent({
    super.key,
    required this.business,
    required this.onNegocioUpdated,
    required this.onOpenReviews,
    required this.onOpenExperiencias,
  });

  @override
  State<BusinessDashboardContent> createState() => _BusinessDashboardContentState();
}

class _BusinessDashboardContentState extends State<BusinessDashboardContent> {
  Future<void> _openEdit() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => BusinessEditPage(business: widget.business)),
    );
    if (changed == true && mounted) {
      setState(() {});
      widget.onNegocioUpdated();
    }
  }

  Future<void> _openGallery() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => BusinessGalleryPage(business: widget.business)),
    );
    if (changed == true && mounted) {
      setState(() {});
      widget.onNegocioUpdated();
    }
  }

  @override
  Widget build(BuildContext context) {
    final business = widget.business;

    return SingleChildScrollView(
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
                if (business.verified) _buildStatsGrid(business) else _buildEstadoBanner(business),
                const SizedBox(height: 28),
                Text(
                  'Gestionar negocio',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                _buildManageGrid(),
                if (business.verified) ...[
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Reseñas recientes',
                        style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      GestureDetector(
                        onTap: widget.onOpenReviews,
                        child: Text(
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
                ],
                const SizedBox(height: 24),
              ],
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
                  colors: [AppColors.scrimDark.withOpacity(0.92), AppColors.scrimDark.withOpacity(0.4)],
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
                            color: Color(0xFFF97316), fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 2),
                      ),
                      if (business.verified) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.check_circle, size: 12, color: Color(0xFF22D3EE)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(business.businessName,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 22, color: Colors.white)),
                  const SizedBox(height: 2),
                  Text(business.category, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEstadoBanner(BusinessProfile business) {
    final rechazado = business.estado == 'rechazado';
    final color = rechazado ? AppColors.errorRed : AppColors.amber;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(rechazado ? Icons.cancel_outlined : Icons.hourglass_top, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rechazado ? 'Solicitud rechazada' : 'Pendiente de aprobación',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  rechazado
                      ? 'Un administrador rechazó este negocio. Puedes actualizar la información e intentarlo de nuevo.'
                      : 'Un administrador revisará esta solicitud pronto. Mientras tanto puedes completar la información.',
                  style: TextStyle(color: AppColors.slate400, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
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
          childAspectRatio: 1.1,
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
                  Text(label, style: TextStyle(color: AppColors.slate400, fontSize: 11)),
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
      (Icons.image_outlined, 'Gestionar fotos', AppColors.businessOrange, _openGallery),
      (Icons.view_in_ar_outlined, 'Mapa y experiencias', AppColors.emerald, widget.onOpenExperiencias),
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
              color: AppColors.overlay(0.03),
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.overlay(0.08)),
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
                        style: TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w500),
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
          Icon(Icons.info_outline, size: 16, color: AppColors.businessOrange),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Completa tu perfil de negocio',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  'Agrega horarios detallados y al menos 5 fotos para aparecer destacado en el mapa.',
                  style: TextStyle(color: AppColors.slate400, fontSize: 12),
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: _openEdit,
                  child: Text(
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
        color: AppColors.overlay(0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.overlay(0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.brandTeal.withOpacity(0.15),
            child: Text(review.initials, style: TextStyle(color: AppColors.brandTeal, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(review.author, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                    Row(
                      children: [
                        Row(
                          children: List.generate(
                            5,
                            (i) => Icon(Icons.star, size: 11, color: i < review.rating ? Colors.amber : AppColors.overlay(0.15)),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(review.dateLabel, style: TextStyle(color: AppColors.slate500, fontSize: 10)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  review.text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
