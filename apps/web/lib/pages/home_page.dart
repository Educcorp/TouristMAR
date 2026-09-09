import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/session_storage.dart';
import '../theme/app_theme.dart';
import '../theme/breakpoints.dart';
import '../widgets/place_card.dart';
import '../widgets/quick_action_card.dart';
import '../widgets/register_place_banner.dart';
import 'login_page.dart';

class _QuickAction {
  final IconData icon;
  final String label;
  final Color accent;
  const _QuickAction(this.icon, this.label, this.accent);
}

class _FeaturedPlace {
  final String image;
  final String category;
  final String name;
  final double rating;
  bool favorite;
  _FeaturedPlace(this.image, this.category, this.name, this.rating, this.favorite);
}

class HomePage extends StatefulWidget {
  final AuthUser user;

  const HomePage({super.key, required this.user});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _quickActions = const [
    _QuickAction(Icons.map_outlined, 'Explorar mapa', AppColors.brandTeal),
    _QuickAction(Icons.favorite_border, 'Mis favoritos', AppColors.orange),
    _QuickAction(Icons.add, 'Proponer lugar', AppColors.brandTeal),
    _QuickAction(Icons.notifications_outlined, 'Notificaciones', AppColors.amber),
  ];

  late final List<_FeaturedPlace> _places = [
    _FeaturedPlace('assets/images/place-playa-audiencia.jpg', 'Playas', 'Playa Audiencia', 4.9, false),
    _FeaturedPlace('assets/images/place-cerro-vigia.jpg', 'Miradores', 'Cerro del Vigía', 4.8, true),
    _FeaturedPlace('assets/images/place-laguna-cuyutlan.jpg', 'Recreación', 'Laguna de Cuyutlán', 4.6, false),
  ];

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Buenos días';
    if (hour < 19) return 'Buenas tardes';
    return 'Buenas noches';
  }

  void _logout() {
    SessionStorage.clearToken();
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginPage()));
  }

  @override
  Widget build(BuildContext context) {
    final firstName = widget.user.name.trim().isEmpty ? widget.user.name : widget.user.name.split(' ').first;

    return Scaffold(
      backgroundColor: AppColors.panelNavy,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 960),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeroCard(firstName),
                        const SizedBox(height: 20),
                        _buildSearchBar(),
                        const SizedBox(height: 28),
                        const Text(
                          'Acciones rápidas',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 12),
                        _buildQuickActions(),
                        const SizedBox(height: 28),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Lugares destacados',
                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                            const Text(
                              'Ver todos',
                              style: TextStyle(color: AppColors.brandTeal, fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildFeaturedPlaces(),
                        const SizedBox(height: 24),
                        RegisterPlaceBanner(onTap: () {}),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.panelNavy,
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.08))),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(color: AppColors.brandTeal, shape: BoxShape.circle),
            child: const Icon(Icons.waves, size: 18, color: AppColors.panelNavy),
          ),
          const SizedBox(width: 8),
          const Text(
            'TOURISMAR',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, letterSpacing: 2, fontSize: 13),
          ),
          const Spacer(),
          Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.notifications_none, color: AppColors.slate300),
              Positioned(
                right: -1,
                top: -1,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(color: AppColors.orange, shape: BoxShape.circle),
                ),
              ),
            ],
          ),
          const SizedBox(width: 20),
          PopupMenuButton<String>(
            offset: const Offset(0, 44),
            color: AppColors.panelNavySoft,
            onSelected: (value) {
              if (value == 'logout') _logout();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'logout', child: Text('Cerrar sesión', style: TextStyle(color: Colors.white))),
            ],
            child: CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.brandTeal.withOpacity(0.2),
              child: Text(
                widget.user.name.isNotEmpty ? widget.user.name[0].toUpperCase() : '?',
                style: const TextStyle(color: AppColors.brandTeal, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard(String firstName) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: 200,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset('assets/images/hero-manzanillo.jpg', fit: BoxFit.cover, alignment: Alignment.centerLeft),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomLeft,
                  end: Alignment.topRight,
                  colors: [AppColors.panelNavy.withOpacity(0.9), AppColors.panelNavy.withOpacity(0.35)],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Text(
                    'MANZANILLO · COLIMA',
                    style: TextStyle(color: AppColors.brandTeal, fontWeight: FontWeight.w600, fontSize: 11, letterSpacing: 2),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$_greeting, $firstName ☀️',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 24),
                  ),
                  const SizedBox(height: 2),
                  const Text('¿Qué vas a explorar hoy?', style: TextStyle(color: AppColors.slate300, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.panelNavySoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, size: 18, color: AppColors.slate500),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                hintText: 'Buscar playas, restaurantes, miradores...',
                hintStyle: const TextStyle(color: AppColors.slate500),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
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
          children: _quickActions
              .map((action) => QuickActionCard(icon: action.icon, label: action.label, accent: action.accent))
              .toList(),
        );
      },
    );
  }

  Widget _buildFeaturedPlaces() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = Breakpoints.isCompact(constraints.maxWidth);
        final cardWidth = isNarrow ? constraints.maxWidth : (constraints.maxWidth - 24) / 3;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _places
              .map(
                (place) => SizedBox(
                  width: cardWidth,
                  child: PlaceCard(
                    image: place.image,
                    category: place.category,
                    name: place.name,
                    rating: place.rating,
                    isFavorite: place.favorite,
                    onToggleFavorite: () => setState(() => place.favorite = !place.favorite),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}
