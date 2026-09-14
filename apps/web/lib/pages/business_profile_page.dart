import 'package:flutter/material.dart';

import '../models/business_profile.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/app_shell.dart';
import '../widgets/cover_image.dart';
import 'business_edit_page.dart';
import 'business_gallery_page.dart';
import 'business_reviews_page.dart';

class BusinessProfilePage extends StatefulWidget {
  final BusinessProfile business;

  const BusinessProfilePage({super.key, required this.business});

  @override
  State<BusinessProfilePage> createState() => _BusinessProfilePageState();
}

class _BusinessProfilePageState extends State<BusinessProfilePage> {
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

  Future<void> _openGallery() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => BusinessGalleryPage(business: widget.business)),
    );
    if (changed == true && mounted) setState(() {});
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
        child: Icon(Icons.apartment, size: 16, color: AppColors.businessOrange),
      ),
      drawerIdentity: BusinessIdentityCard(business: business),
      navItems: businessNavItems(context, business: business, current: BusinessSection.profile),
      body: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(
              height: 200,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CoverImage(source: business.coverImage),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, AppColors.scrimDark.withOpacity(0.9)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Transform.translate(
                        offset: const Offset(0, -36),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              width: 76,
                              height: 76,
                              decoration: BoxDecoration(
                                color: AppColors.panelNavySoft,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: AppColors.businessOrange.withOpacity(0.4), width: 2),
                              ),
                              child: Icon(Icons.apartment, size: 30, color: AppColors.businessOrange),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            business.businessName,
                                            style: Theme.of(context)
                                                .textTheme
                                                .headlineMedium
                                                ?.copyWith(fontSize: 20, color: Colors.white),
                                          ),
                                        ),
                                        if (business.verified) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: AppColors.brandTeal.withOpacity(0.15),
                                              borderRadius: BorderRadius.circular(999),
                                              border: Border.all(color: AppColors.brandTeal.withOpacity(0.3)),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.check_circle, size: 10, color: AppColors.brandTeal),
                                                SizedBox(width: 4),
                                                Text('Verificado',
                                                    style: TextStyle(
                                                        color: AppColors.brandTeal, fontSize: 10, fontWeight: FontWeight.w700)),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    Text(business.category, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              ...List.generate(
                                5,
                                (i) => Icon(Icons.star,
                                    size: 15, color: i < business.rating.round() ? Colors.amber : AppColors.overlay(0.15)),
                              ),
                              const SizedBox(width: 8),
                              Text('${business.rating}', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
                              const SizedBox(width: 4),
                              Text('(${business.totalReviews} reseñas)', style: TextStyle(color: AppColors.slate400, fontSize: 12)),
                            ],
                          ),
                          AppButton(
                            variant: AppButtonVariant.ghost,
                            onPressed: _openEdit,
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.edit_outlined, size: 13),
                                SizedBox(width: 6),
                                Text('Editar'),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _card(
                        title: 'DESCRIPCIÓN',
                        child: Text(business.description, style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.4)),
                      ),
                      const SizedBox(height: 16),
                      _card(
                        title: 'INFORMACIÓN DE CONTACTO',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _contactRow(Icons.place_outlined, business.address),
                            const SizedBox(height: 10),
                            _contactRow(Icons.phone_outlined, business.phone),
                            const SizedBox(height: 10),
                            _contactRow(Icons.language, business.website),
                            const SizedBox(height: 10),
                            _contactRow(Icons.schedule_outlined, business.hours),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Galería de fotos', style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                          GestureDetector(
                            onTap: _openGallery,
                            child: Text('Gestionar', style: TextStyle(color: AppColors.businessOrange, fontSize: 12, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _buildGallery(business),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Últimas reseñas', style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                          GestureDetector(
                            onTap: _openReviews,
                            child: Text('Ver todas', style: TextStyle(color: AppColors.brandTeal, fontSize: 12, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ...businessReviews.take(2).map((r) => _buildReviewPreview(r)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.panelNavySoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.overlay(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: AppColors.slate500, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1)),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _contactRow(IconData icon, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: AppColors.brandTeal),
        const SizedBox(width: 10),
        Expanded(child: Text(value, style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5))),
      ],
    );
  }

  Widget _buildGallery(BusinessProfile business) {
    return LayoutBuilder(builder: (context, constraints) {
      final tileSize = (constraints.maxWidth - 16) / 3;
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ...business.gallery.map((img) => ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: tileSize,
                  height: tileSize,
                  child: CoverImage(source: img),
                ),
              )),
          GestureDetector(
            onTap: _openGallery,
            child: Container(
              width: tileSize,
              height: tileSize,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.overlay(0.15), style: BorderStyle.solid),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add, size: 18, color: AppColors.slate400),
                  SizedBox(height: 2),
                  Text('Agregar', style: TextStyle(color: AppColors.slate400, fontSize: 9)),
                ],
              ),
            ),
          ),
        ],
      );
    });
  }

  Widget _buildReviewPreview(BusinessReview r) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
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
                    radius: 14,
                    backgroundColor: AppColors.brandTeal.withOpacity(0.15),
                    child: Text(r.initials, style: TextStyle(color: AppColors.brandTeal, fontSize: 10, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.author, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 12.5)),
                      Text(r.dateLabel, style: TextStyle(color: AppColors.slate500, fontSize: 10)),
                    ],
                  ),
                ],
              ),
              Row(
                children: List.generate(5, (i) => Icon(Icons.star, size: 11, color: i < r.rating ? Colors.amber : AppColors.overlay(0.15))),
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
