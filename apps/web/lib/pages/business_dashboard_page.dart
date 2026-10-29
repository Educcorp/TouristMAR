import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/lugar.dart';
import '../models/business_profile.dart';
import '../theme/app_theme.dart';
import '../services/resenas_service.dart';
import '../widgets/cover_image.dart';
import '../widgets/resenas/resenas_widgets.dart';
import '../widgets/tablero_cifras.dart';

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
  List<Resena>? _resenas;

  @override
  void initState() {
    super.initState();
    _cargarResenas();
  }

  Future<void> _cargarResenas() async {
    if (!widget.business.verified) return;
    final (datos, _) = await (widget.business.cargarResenas(), widget.business.cargarEstadisticas()).wait;
    if (!mounted) return;
    setState(() => _resenas = datos?.resenas ?? const []);
  }

  Future<void> _openEdit() async {
    final changed = await context.push<bool>('/empresa/editar?negocio=${widget.business.id}');
    if (changed == true && mounted) {
      setState(() {});
      widget.onNegocioUpdated();
    }
  }

  Future<void> _openGallery() async {
    final changed = await context.push<bool>('/empresa/galeria?negocio=${widget.business.id}');
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
                          style: TextStyle(color: AppColors.businessOrange, fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ResenasRecientes(resenas: _resenas),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// El negocio como casco: foto, franja del color de su categoría y datos.
  /// En pantallas anchas la foto va a la izquierda en 16:9 (a lo ancho de
  /// la columna recortaba la portada, sobre todo los logos).
  Widget _buildHero(BusinessProfile business) {
    final cat = CategoriaLugarDetector.detectar(business.category);
    final datos = Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(business.businessName, style: AppTypography.h1.copyWith(fontSize: 28)),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(cat.icon, size: 18, color: cat.color),
              const SizedBox(width: 6),
              Flexible(child: Text(business.category, style: AppTypography.bodySmall.copyWith(fontSize: 15))),
              if (business.verified) ...[
                const SizedBox(width: 12),
                Icon(Icons.verified_outlined, size: 18, color: AppColors.turquesaTexto),
                const SizedBox(width: 4),
                Text('Verificado', style: AppTypography.bodySmall.copyWith(color: AppColors.turquesaTexto)),
              ],
            ],
          ),
        ],
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.cubierta,
          border: Border.all(color: AppColors.borderSubtle),
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: LayoutBuilder(builder: (context, constraints) {
          if (constraints.maxWidth < 640) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(aspectRatio: 16 / 9, child: CoverImage(source: business.coverImage)),
                Container(height: kFranja, color: cat.esmalte),
                datos,
              ],
            );
          }
          // La franja sigue siendo horizontal (la línea de flotación bajo la
          // foto), no una raya lateral.
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 320,
                child: Column(
                  children: [
                    AspectRatio(aspectRatio: 16 / 9, child: CoverImage(source: business.coverImage)),
                    Container(height: kFranja, color: cat.esmalte),
                  ],
                ),
              ),
              Expanded(child: datos),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildEstadoBanner(BusinessProfile business) {
    final rechazado = business.estado == 'rechazado';
    final color = rechazado ? AppColors.rojo : AppColors.amarillo;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.cubierta,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(height: kFranja, color: color),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(rechazado ? Icons.cancel_outlined : Icons.hourglass_top,
                    color: rechazado ? AppColors.rojoTexto : AppColors.amarilloTexto),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(rechazado ? 'Solicitud rechazada' : 'Pendiente de aprobación', style: AppTypography.h3),
                      const SizedBox(height: 4),
                      Text(
                        rechazado
                            ? 'Un administrador rechazó este negocio. Puedes actualizar la información e intentarlo de nuevo.'
                            : 'Un administrador revisará esta solicitud pronto. Mientras tanto puedes completar la información.',
                        style: AppTypography.body.copyWith(fontSize: 15),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Las cuatro cifras del mes en una sola tira, como un tablero: celdas
  /// separadas por filetes, números en la letra de matrícula.
  Widget _buildStatsGrid(BusinessProfile business) {
    final calificacion = business.totalReviews == 0
        ? ('—', 'Sin reseñas todavía')
        : (business.rating.toStringAsFixed(1), 'Calificación · ${business.totalReviews} ${business.totalReviews == 1 ? 'reseña' : 'reseñas'}');
    return TableroCifras(celdas: [
      // Veces que abrieron la ficha del negocio en los últimos 30 días (un
      // mismo visitante cuenta una vez al día).
      CeldaCifra(Icons.people_outline, '${business.monthlyVisits}', 'Visitas a tu ficha · 30 días'),
      CeldaCifra(Icons.star_outline, calificacion.$1, calificacion.$2),
      CeldaCifra(Icons.forum_outlined, '${business.newReviews}', 'Reseñas del mes'),
      CeldaCifra(Icons.favorite_border, '${business.favorites}', 'En favoritos'),
    ]);
  }

  Widget _buildManageGrid() {
    final acciones = [
      (Icons.edit_outlined, 'Editar información', 'Nombre, horario, contacto y ubicación', _openEdit),
      (Icons.image_outlined, 'Gestionar fotos', 'Portada y galería', _openGallery),
      (Icons.view_in_ar_outlined, 'Mapa y experiencias', 'Pin del mapa, RA y recorrido 360°', widget.onOpenExperiencias),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cubierta,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < acciones.length; i++) ...[
            if (i > 0) Divider(height: 1, color: AppColors.borderSubtle),
            ListTile(
              onTap: acciones[i].$4,
              minTileHeight: 64,
              leading: Icon(acciones[i].$1, color: AppColors.tinta),
              title: Text(acciones[i].$2, style: AppTypography.h3),
              subtitle: Text(acciones[i].$3, style: AppTypography.caption.copyWith(color: AppColors.slate400)),
              trailing: Icon(Icons.chevron_right, color: AppColors.slate400),
            ),
          ],
        ],
      ),
    );
  }
}
