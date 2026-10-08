import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/business_profile.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import '../services/resenas_service.dart';
import '../utils/contact_launcher.dart';
import '../widgets/cover_image.dart';
import '../widgets/resenas/resenas_widgets.dart';

/// Contenido de la sección "Mi negocio" embebido en [BusinessShell] — sin
/// Scaffold/AppBar propio, igual que las páginas del panel admin.
class BusinessProfileContent extends StatefulWidget {
  final BusinessProfile business;
  final VoidCallback onNegocioUpdated;
  final VoidCallback onOpenReviews;

  const BusinessProfileContent({
    super.key,
    required this.business,
    required this.onNegocioUpdated,
    required this.onOpenReviews,
  });

  @override
  State<BusinessProfileContent> createState() => _BusinessProfileContentState();
}

class _BusinessProfileContentState extends State<BusinessProfileContent> {
  List<Resena>? _resenas;

  @override
  void initState() {
    super.initState();
    _cargarResenas();
  }

  Future<void> _cargarResenas() async {
    if (!widget.business.verified) return;
    final datos = await widget.business.cargarResenas();
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
                      colors: [Colors.transparent, AppColors.scrimDark.withValues(alpha: 0.9)],
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
                              border: Border.all(color: AppColors.businessOrange.withValues(alpha: 0.4), width: 2),
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
                                      const SizedBox(width: 8),
                                      _EstadoBadge(estado: business.estado),
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
                        IntrinsicWidth(
                          child: AppButton(
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
                          _contactRow(
                            Icons.place_outlined,
                            business.address,
                            onTap: business.address.trim().isEmpty
                                ? null
                                : () => abrirDireccionEnMapa(business.address, latitud: business.latitud, longitud: business.longitud),
                          ),
                          const SizedBox(height: 10),
                          _contactRow(
                            Icons.phone_outlined,
                            business.phone,
                            onTap: business.phone.trim().isEmpty ? null : () => abrirTelefono(business.phone),
                          ),
                          const SizedBox(height: 10),
                          _contactRow(
                            Icons.language,
                            business.website,
                            onTap: business.website.trim().isEmpty ? null : () => abrirSitioWeb(business.website),
                          ),
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
                    if (business.verified) ...[
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Últimas reseñas', style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                          GestureDetector(
                            onTap: widget.onOpenReviews,
                            child: Text('Ver todas', style: TextStyle(color: AppColors.brandTeal, fontSize: 12, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ResenasRecientes(resenas: _resenas),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
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

  Widget _contactRow(IconData icon, String value, {VoidCallback? onTap}) {
    final texto = Text(
      value,
      style: TextStyle(
        color: onTap == null ? AppColors.textSecondary : AppColors.brandTeal,
        fontSize: 13.5,
        decoration: onTap == null ? null : TextDecoration.underline,
        decorationColor: AppColors.brandTeal.withValues(alpha: 0.5),
      ),
    );
    final fila = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: AppColors.brandTeal),
        const SizedBox(width: 10),
        Expanded(child: texto),
      ],
    );
    if (onTap == null) return fila;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(onTap: onTap, child: fila),
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
                  const SizedBox(height: 2),
                  Text('Agregar', style: TextStyle(color: AppColors.slate400, fontSize: 9)),
                ],
              ),
            ),
          ),
        ],
      );
    });
  }
}

class _EstadoBadge extends StatelessWidget {
  final String estado;

  const _EstadoBadge({required this.estado});

  @override
  Widget build(BuildContext context) {
    final color = switch (estado) {
      'aprobado' => AppColors.brandTeal,
      'rechazado' => AppColors.errorRed,
      _ => AppColors.amber,
    };
    final label = switch (estado) {
      'aprobado' => 'Verificado',
      'rechazado' => 'Rechazado',
      _ => 'Pendiente',
    };
    final icon = switch (estado) {
      'aprobado' => Icons.check_circle,
      'rechazado' => Icons.cancel,
      _ => Icons.hourglass_top,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
