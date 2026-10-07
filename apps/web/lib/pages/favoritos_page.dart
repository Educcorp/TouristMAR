import 'package:flutter/material.dart';

import '../models/lugar.dart';
import '../models/visitor_profile.dart';
import '../navegacion/rutas.dart';
import '../services/favoritos_service.dart';
import '../theme/app_theme.dart';
import '../theme/breakpoints.dart';
import '../widgets/app_shell.dart';
import '../widgets/place_card.dart';
import '../widgets/themed_builder.dart';
import '../widgets/user_avatar.dart';

/// "Mis favoritos": los lugares que el visitante guardó con el corazón.
class FavoritosPage extends StatefulWidget {
  final VisitorProfile profile;

  const FavoritosPage({super.key, required this.profile});

  @override
  State<FavoritosPage> createState() => _FavoritosPageState();
}

class _FavoritosPageState extends State<FavoritosPage> {
  List<Lugar> _lugares = const [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    FavoritosService.instance.ids.addListener(_alCambiarIds);
    _cargar();
  }

  @override
  void dispose() {
    FavoritosService.instance.ids.removeListener(_alCambiarIds);
    super.dispose();
  }

  /// Quitar un favorito (aquí o en la ficha) lo saca de la lista al instante.
  void _alCambiarIds() {
    if (!mounted) return;
    final ids = FavoritosService.instance.ids.value;
    setState(() => _lugares = _lugares.where((l) => ids.contains(l.id)).toList());
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final lugares = await FavoritosService.instance.listar();
      if (!mounted) return;
      setState(() {
        _lugares = lugares;
        _cargando = false;
      });
    } on FavoritosError catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo conectar con el servidor';
        _cargando = false;
      });
    }
  }

  Future<void> _quitar(Lugar lugar) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await FavoritosService.instance.alternar(lugar.id);
    } on FavoritosError catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
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
      navItems: visitorNavItems(context, profile: profile, current: VisitorSection.favoritos),
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            // Ocupa todo el ancho posible (hasta 960): si no, la columna
            // se encoge al elemento más ancho (la tarjeta) y se centra.
            child: SizedBox(
              width: double.infinity,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Mis favoritos', style: AppTypography.h2),
                    const SizedBox(height: 4),
                    Text('Los lugares que guardaste para volver a visitar.', style: AppTypography.bodySmall),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      _cargando
                          ? 'Cargando…'
                          : '${_lugares.length} ${_lugares.length == 1 ? 'lugar' : 'lugares'}',
                      style: AppTypography.caption,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _buildContenido(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContenido() {
    if (_cargando) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 64),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return _Mensaje(
        icon: Icons.cloud_off_outlined,
        titulo: _error!,
        accion: TextButton(onPressed: _cargar, child: const Text('Reintentar')),
      );
    }
    if (_lugares.isEmpty) {
      return _Mensaje(
        icon: Icons.favorite_border,
        titulo: 'Aún no tienes favoritos',
        detalle: 'Toca el corazón en un lugar para guardarlo aquí.',
        accion: TextButton(
          onPressed: () => openVisitorMap(context, widget.profile),
          child: const Text('Explorar el mapa'),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columnas = Breakpoints.isCompact(constraints.maxWidth) ? 1 : 3;
        final ancho = (constraints.maxWidth - 12 * (columnas - 1)) / columnas;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _lugares
              .map((lugar) => SizedBox(
                    width: ancho,
                    child: PlaceCard(
                      image: lugar.portada,
                      category: lugar.categoriaTexto.isEmpty ? lugar.categoria.etiqueta : lugar.categoriaTexto,
                      name: lugar.nombre,
                      rating: lugar.rating,
                      isFavorite: true,
                      onTap: () => abrirLugar(context, lugar),
                      onToggleFavorite: () => _quitar(lugar),
                    ),
                  ))
              .toList(),
        );
      },
    );
  }
}

class _Mensaje extends StatelessWidget {
  final IconData icon;
  final String titulo;
  final String? detalle;
  final Widget? accion;

  const _Mensaje({required this.icon, required this.titulo, this.detalle, this.accion});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 44, color: AppColors.slate500),
            const SizedBox(height: 12),
            Text(titulo, textAlign: TextAlign.center, style: AppTypography.h3),
            if (detalle != null) ...[
              const SizedBox(height: 4),
              Text(detalle!, textAlign: TextAlign.center, style: AppTypography.body),
            ],
            if (accion != null) ...[const SizedBox(height: 8), accion!],
          ],
        ),
      ),
    );
  }
}
