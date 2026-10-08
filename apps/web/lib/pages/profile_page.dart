import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/visitor_profile.dart';
import '../services/favoritos_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/app_shell.dart';
import '../widgets/themed_builder.dart';
import '../widgets/user_avatar.dart';

class ProfilePage extends StatefulWidget {
  final VisitorProfile profile;

  const ProfilePage({super.key, required this.profile});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  @override
  void initState() {
    super.initState();
    widget.profile.cargarResenas().then((_) {
      if (mounted) setState(() {});
    });
    FavoritosService.instance.cargarIds();
  }

  Future<void> _editProfile() async {
    final changed = await context.push<bool>('/perfil/editar');
    if (changed == true && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => ThemedBuilder(builder: _buildShell);

  Widget _buildShell(BuildContext context) {
    final profile = widget.profile;

    return AppShell(
      accentColor: AppColors.brandTeal,
      avatarIcon: UserAvatar(imageUrl: profile.avatarUrl, fallbackLetter: profile.name),
      drawerIdentity: VisitorIdentityCard(
        name: profile.name,
        email: profile.email,
        avatarUrl: profile.avatarUrl,
        reviewsCount: profile.reviews.length,
      ),
      navItems: visitorNavItems(context, profile: profile, current: VisitorSection.profile),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildCoverHero(profile),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStatsRow(profile),
                      if (profile.bio.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        _buildBioCard(profile),
                      ],
                      const SizedBox(height: 16),
                      AppButton(
                        variant: AppButtonVariant.ghost,
                        onPressed: _editProfile,
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.edit_outlined, size: 15),
                            SizedBox(width: 8),
                            Text('Editar perfil'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      _buildSectionHeader('Mis reseñas', '${profile.reviews.length} en total'),
                      const SizedBox(height: 12),
                      _buildReviews(profile),
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

  Widget _buildCoverHero(VisitorProfile profile) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          color: AppColors.riel,
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            children: [
              UserAvatar(imageUrl: profile.avatarUrl, fallbackLetter: profile.name, radius: 44),
              const SizedBox(height: 14),
              Text(profile.name, style: AppTypography.h1.copyWith(color: AppColors.sobreRiel, fontSize: 26)),
              const SizedBox(height: 4),
              Text(profile.email, style: const TextStyle(color: AppColors.sobreRielSuave, fontSize: 15)),
            ],
          ),
        ),
        Row(
          children: [
            for (final c in const [AppColors.turquesa, AppColors.amarillo, AppColors.azul, AppColors.rojo])
              Expanded(child: Container(height: kFranja, color: c)),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsRow(VisitorProfile profile) {
    final stats = [
      (Icons.favorite_border, '${FavoritosService.instance.ids.value.length}', 'Favoritos'),
      (Icons.forum_outlined, '${profile.reviews.length}', 'Reseñas escritas'),
      (Icons.star_outline, profile.promedioDadas == null ? '—' : profile.promedioDadas!.toStringAsFixed(1), 'Calificación que das'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.panelNavySoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.overlay(0.08)),
      ),
      child: Row(
        children: stats.map((s) {
          final (icon, value, label) = s;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                children: [
                  Icon(icon, size: 20, color: AppColors.slate400),
                  const SizedBox(height: 6),
                  Text(value, style: AppTypography.cifra(size: 28)),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.slate400, fontSize: 13),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBioCard(VisitorProfile profile) {
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
          Text('Sobre mí', style: AppTypography.h3),
          const SizedBox(height: 8),
          Text(profile.bio, style: AppTypography.body),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, String trailing) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: AppTypography.h2),
        Text(trailing, style: TextStyle(color: AppColors.slate400, fontSize: 12)),
      ],
    );
  }

  Widget _buildReviews(VisitorProfile profile) {
    if (profile.reviews.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.panelNavySoft,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.overlay(0.08)),
        ),
        child: Text(
          'Aún no has escrito reseñas. Abre un lugar y cuéntanos tu experiencia.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.slate400, fontSize: 13),
        ),
      );
    }
    return Column(
      children: profile.reviews.map((review) => _ReviewTile(review: review)).toList(),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  final UserReview review;

  const _ReviewTile({required this.review});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(review.placeName,
                      style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                  Text(review.dateLabel, style: TextStyle(color: AppColors.slate500, fontSize: 12)),
                ],
              ),
              Row(
                children: List.generate(
                  5,
                  (i) => Icon(
                    Icons.star,
                    size: 13,
                    color: i < review.rating ? Colors.amber : AppColors.overlay(0.15),
                  ),
                ),
              ),
            ],
          ),
          if (review.text.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(review.text, style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4)),
          ],
          if (review.reply != null && review.reply!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.overlay(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Respuesta del negocio',
                      style: TextStyle(color: AppColors.brandTeal, fontSize: 12, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(review.reply!, style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
