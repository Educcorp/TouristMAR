import 'package:flutter/material.dart';

import '../models/visitor_profile.dart';
import '../models/lugar.dart';
import '../navegacion/rutas.dart';
import '../navegacion/sesion.dart';
import '../services/auth_service.dart';
import '../services/favoritos_service.dart';
import '../services/lugares_service.dart';
import '../theme/app_theme.dart';
import '../theme/breakpoints.dart';
import '../widgets/app_shell.dart';
import '../widgets/place_card.dart';
import '../widgets/quick_action_card.dart';
import '../widgets/register_place_banner.dart';
import '../widgets/themed_builder.dart';
import '../utils/keyboard.dart';
import '../widgets/user_avatar.dart';
import '../widgets/notification_bell.dart';

class _QuickAction {
  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback? onTap;
  const _QuickAction(this.icon, this.label, this.accent, [this.onTap]);
}

class _FeaturedPlace {
  final String lugarId;
  final String image;
  final String category;
  final String name;
  final double rating;
  _FeaturedPlace(this.lugarId, this.image, this.category, this.name, this.rating);
}

class HomePage extends StatefulWidget {
  final AuthUser user;

  const HomePage({super.key, required this.user});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  /// El mismo perfil que usan "Mi perfil" y "Editar perfil"
  /// ([Sesion.perfilVisitante]). Antes el inicio armaba su propia copia desde
  /// `widget.user` (lo que regresó el servidor al iniciar sesión), así que
  /// después de cambiar la foto seguía mostrando la anterior hasta recargar
  /// la página. Si el inicio se abre sin sesión registrada (p. ej. en
  /// pruebas), se arma desde `widget.user` como antes.
  late final VisitorProfile _profile = Sesion.usuario.value?.id == widget.user.id
      ? Sesion.perfilVisitante
      : VisitorProfile.fromAuthUser(widget.user);

  @override
  void initState() {
    super.initState();
    // Para que los corazones de tarjetas y fichas salgan ya marcados.
    FavoritosService.instance.cargarIds();
    // Y para que el contador de reseñas del menú lateral sea el real.
    _profile.cargarResenas().then((_) {
      if (mounted) setState(() {});
    });
  }

  late final _quickActions = [
    _QuickAction(Icons.map_outlined, 'Explorar mapa', AppColors.brandTeal, () => openVisitorMap(context, _profile)),
    _QuickAction(Icons.favorite_border, 'Mis favoritos', AppColors.orange, () => openVisitorFavoritos(context, _profile)),
    _QuickAction(Icons.add, 'Proponer lugar', AppColors.brandTeal, _proposePlace),
    _QuickAction(
      Icons.notifications_outlined,
      'Notificaciones',
      AppColors.amber,
      () => showNotificationsDialog(context, AppColors.brandTeal),
    ),
  ];

  /// Error 1: el banner "¿Te gustaría registrar un lugar nuevo?" (y la acción
  /// rápida "Proponer lugar") no hacían nada. El backend solo deja registrar
  /// lugares a cuentas de negocio, así que se le explica al visitante y, si
  /// acepta, se cierra su sesión y se abre directo el registro de negocio.
  Future<void> _proposePlace() async {
    final go = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.panelNavySoft,
        title: Text('Registrar un lugar nuevo', style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          'Para proponer tu negocio o sitio turístico necesitas una cuenta de negocio. '
          'Al continuar se cerrará tu sesión de visitante y te llevaremos al registro de negocio. '
          'Un administrador revisará la solicitud antes de que aparezca en el mapa.',
          style: TextStyle(color: AppColors.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('Cancelar', style: TextStyle(color: AppColors.slate400)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('Continuar', style: TextStyle(color: AppColors.brandTeal, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (go != true || !mounted) return;

    cerrarSesion(context, registroNegocio: true);
  }

  late final List<_FeaturedPlace> _places = [
    _FeaturedPlace('demo-audiencia', 'assets/images/place-playa-audiencia.jpg', 'Playas', 'Playa Audiencia', 4.9),
    _FeaturedPlace('demo-vigia', 'assets/images/place-cerro-vigia.jpg', 'Miradores', 'Cerro del Vigía', 4.8),
    _FeaturedPlace('demo-cuyutlan', 'assets/images/place-laguna-cuyutlan.jpg', 'Recreación', 'Laguna de Cuyutlán', 4.6),
  ];

  Future<void> _openPlace(String lugarId) async {
    final lugares = await const LugaresService().listarPublicos();
    final lugar = lugares.where((l) => l.id == lugarId).firstOrNull;
    if (lugar == null || !mounted) return;
    await abrirLugar(context, lugar);
  }

  /// Las tarjetas destacadas de hoy son lugares de ejemplo (sin registro en
  /// la base de datos), así que todavía no se pueden guardar; en cuanto sean
  /// negocios reales el corazón funciona igual que en la ficha del lugar.
  Future<void> _toggleFavorite(String lugarId) async {
    final messenger = ScaffoldMessenger.of(context);
    if (!Lugar.idEsReal(lugarId)) {
      messenger.showSnackBar(const SnackBar(content: Text('Este lugar es de ejemplo y aún no se puede guardar en favoritos')));
      return;
    }
    try {
      await FavoritosService.instance.alternar(lugarId);
    } on FavoritosError catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Buenos días';
    if (hour < 19) return 'Buenas tardes';
    return 'Buenas noches';
  }

  @override
  Widget build(BuildContext context) => ThemedBuilder(builder: _buildShell);

  Widget _buildShell(BuildContext context) {
    // También del perfil compartido: si cambió el nombre, el saludo ya sale nuevo.
    final firstName = _profile.name.trim().isEmpty ? _profile.name : _profile.name.trim().split(' ').first;

    return AppShell(
      accentColor: AppColors.brandTeal,
      // Se lee de `_profile` (el que edita "Editar perfil"), no de
      // `widget.user`, para que el inicio muestre la foto/nombre guardados.
      avatarIcon: UserAvatar(imageUrl: _profile.avatarUrl, fallbackLetter: _profile.name),
      drawerIdentity: VisitorIdentityCard(
        name: _profile.name,
        email: _profile.email,
        avatarUrl: _profile.avatarUrl,
        visitedCount: _profile.visited.length,
        reviewsCount: _profile.reviews.length,
      ),
      navItems: visitorNavItems(context, profile: _profile, current: VisitorSection.home),
      body: SingleChildScrollView(
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
                  Text(
                    'Acciones rápidas',
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  _buildQuickActions(),
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Flexible + ellipsis: en pantallas angostas o con letra
                      // grande el título ya no empuja "Ver todos" fuera del borde.
                      Flexible(
                        child: Text(
                          'Lugares destacados',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Ver todos',
                        style: TextStyle(color: AppColors.brandTeal, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildFeaturedPlaces(),
                  const SizedBox(height: 24),
                  RegisterPlaceBanner(onTap: _proposePlace),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
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
                  colors: [AppColors.scrimDark.withValues(alpha: 0.9), AppColors.scrimDark.withValues(alpha: 0.35)],
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
                    style: TextStyle(color: Color(0xFF22D3EE), fontWeight: FontWeight.w600, fontSize: 11, letterSpacing: 2),
                  ),
                  const SizedBox(height: 6),
                  // Ícono en vez de emoji: el emoji ☀️ lleva un selector de
                  // variante (U+FE0F) que ninguna fuente Noto cubre, y Flutter
                  // web avisaba en consola que no podía dibujarlo.
                  Text.rich(
                    TextSpan(children: [
                      TextSpan(text: '$_greeting, $firstName '),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: Icon(
                          DateTime.now().hour < 19 ? Icons.wb_sunny_rounded : Icons.nightlight_round,
                          size: 22,
                          color: const Color(0xFFFBBF24),
                        ),
                      ),
                    ]),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 24, color: Colors.white),
                  ),
                  const SizedBox(height: 2),
                  const Text('¿Qué vas a explorar hoy?', style: TextStyle(color: Colors.white70, fontSize: 13)),
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
        border: Border.all(color: AppColors.overlay(0.1)),
      ),
      child: Row(
        children: [
          Icon(Icons.search, size: 18, color: AppColors.slate500),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              // Tocar fuera de la barra cierra el teclado (en Android, por
              // defecto, un toque fuera no le quita el foco al campo).
              onTapOutside: (_) => hideKeyboard(),
              style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                hintText: 'Buscar playas, restaurantes, miradores...',
                hintStyle: TextStyle(color: AppColors.slate500),
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
              .map((action) => QuickActionCard(
                    icon: action.icon,
                    label: action.label,
                    accent: action.accent,
                    onTap: action.onTap,
                  ))
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

        return ValueListenableBuilder<Set<String>>(
          valueListenable: FavoritosService.instance.ids,
          builder: (context, _, __) => Wrap(
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
                    isFavorite: FavoritosService.instance.esFavorito(place.lugarId),
                    onTap: () => _openPlace(place.lugarId),
                    onToggleFavorite: () => _toggleFavorite(place.lugarId),
                  ),
                ),
              )
              .toList(),
          ),
        );
      },
    );
  }
}
