import 'package:flutter/material.dart';

import '../models/visitor_profile.dart';
import '../theme/app_theme.dart';
import '../theme/breakpoints.dart';
import '../widgets/app_button.dart';
import '../widgets/app_shell.dart';
import '../widgets/themed_builder.dart';
import '../widgets/user_avatar.dart';
import 'edit_profile_page.dart';

class ProfilePage extends StatefulWidget {
  final VisitorProfile profile;

  const ProfilePage({super.key, required this.profile});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Future<void> _editProfile() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EditProfilePage(profile: widget.profile)),
    );
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
        visitedCount: profile.visited.length,
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
                      _buildSectionHeader('Lugares visitados', '${profile.visited.length} en total'),
                      const SizedBox(height: 12),
                      _buildVisitedGrid(profile),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF14343F), AppColors.scrimDark, Color(0xFF3A2416)],
        ),
      ),
      child: Column(
        children: [
          UserAvatar(imageUrl: profile.avatarUrl, fallbackLetter: profile.name, radius: 44),
          const SizedBox(height: 14),
          Text(profile.name,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 22, color: Colors.white)),
          const SizedBox(height: 4),
          Text(profile.email, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildStatsRow(VisitorProfile profile) {
    final stats = [
      (Icons.place_outlined, '${profile.visited.length}', 'Lugares visitados'),
      (Icons.forum_outlined, '${profile.reviews.length}', 'Reseñas escritas'),
      (Icons.star_outline, '4.7★', 'Valoración media'),
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
                  Icon(icon, size: 16, color: AppColors.brandTeal),
                  const SizedBox(height: 4),
                  Text(value, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 17)),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.slate400, fontSize: 10),
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
          Text(
            'SOBRE MÍ',
            style: TextStyle(color: AppColors.slate500, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1),
          ),
          const SizedBox(height: 8),
          Text(profile.bio, style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.4)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, String trailing) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 17)),
        Text(trailing, style: TextStyle(color: AppColors.slate400, fontSize: 12)),
      ],
    );
  }

  Widget _buildVisitedGrid(VisitorProfile profile) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = Breakpoints.isCompact(constraints.maxWidth);
        final cardWidth = isNarrow ? constraints.maxWidth : (constraints.maxWidth - 24) / 3;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: profile.visited.map((place) {
            return SizedBox(width: cardWidth, child: _VisitedPlaceCard(place: place));
          }).toList(),
        );
      },
    );
  }

  Widget _buildReviews(VisitorProfile profile) {
    return Column(
      children: profile.reviews.map((review) => _ReviewTile(review: review)).toList(),
    );
  }
}

class _VisitedPlaceCard extends StatelessWidget {
  final VisitedPlace place;

  const _VisitedPlaceCard({required this.place});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.panelNavySoft,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(
            aspectRatio: 16 / 10,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(place.image, fit: BoxFit.cover),
                Positioned(
                  left: 8,
                  bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.brandTeal.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      place.category,
                      style: TextStyle(color: AppColors.panelNavy, fontSize: 10, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  place.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.star, size: 12, color: Colors.amber),
                        const SizedBox(width: 3),
                        Text(place.rating.toString(),
                            style: TextStyle(color: AppColors.slate300, fontSize: 11)),
                      ],
                    ),
                    Text(place.dateLabel, style: TextStyle(color: AppColors.slate500, fontSize: 10)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
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
                  Text(review.dateLabel, style: TextStyle(color: AppColors.slate500, fontSize: 11)),
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
          const SizedBox(height: 8),
          Text(review.text, style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4)),
        ],
      ),
    );
  }
}
