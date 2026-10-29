import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../widgets/admin/ds_badge.dart';
import '../models/lugar.dart';
import '../models/business_profile.dart';
import '../theme/app_theme.dart';
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

    final cat = CategoriaLugarDetector.detectar(business.category);
    return SingleChildScrollView(
      child: Column(
        children: [
          // El negocio como lo ve el visitante: foto arriba de la línea de
          // flotación (franja del color de su categoría) y los datos debajo,
          // en tinta. Antes el nombre iba en blanco sobre la foto con un
          // degradado y en muchas portadas no se leía.
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: AppAncho.formulario),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // La portada en 16:9 dentro de la columna (como las
                    // tarjetas del visitante): a todo el ancho del escritorio
                    // recortaba los logos hasta dejarlos ilegibles.
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      child: Column(
                        children: [
                          AspectRatio(aspectRatio: 16 / 9, child: CoverImage(source: business.coverImage)),
                          Container(height: kFranja, color: cat.esmalte),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      children: [
                        Icon(cat.icon, size: 20, color: cat.color),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            business.category.trim().isEmpty ? 'Sin categoría' : business.category,
                            style: AppTypography.bodySmall.copyWith(color: AppColors.slate300, fontSize: 15),
                          ),
                        ),
                        const SizedBox(width: 10),
                        _EstadoBadge(estado: business.estado),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(business.businessName, style: AppTypography.display.copyWith(fontSize: 32)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: business.totalReviews == 0
                              ? Text('Sin reseñas todavía', style: AppTypography.bodySmall)
                              : Row(
                                  children: [
                                    const Icon(Icons.star_rounded, size: 20, color: AppColors.amarillo),
                                    const SizedBox(width: 4),
                                    Text(business.rating.toStringAsFixed(1),
                                        style: AppTypography.h3.copyWith(fontWeight: FontWeight.w700)),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${business.totalReviews} ${business.totalReviews == 1 ? 'reseña' : 'reseñas'}',
                                      style: AppTypography.bodySmall,
                                    ),
                                  ],
                                ),
                        ),
                        OutlinedButton.icon(
                          onPressed: _openEdit,
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: const Text('Editar'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _card(
                      title: 'Descripción',
                      child: Text(business.description, style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.4)),
                    ),
                    const SizedBox(height: 16),
                    _card(
                      title: 'Información de contacto',
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
                          child: Text('Gestionar', style: TextStyle(color: AppColors.businessOrange, fontSize: 13, fontWeight: FontWeight.w600)),
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
                            child: Text('Ver todas', style: TextStyle(color: AppColors.brandTeal, fontSize: 13, fontWeight: FontWeight.w600)),
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
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.cubierta,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.h3),
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
        fontSize: 14,
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
                  Text('Agregar', style: TextStyle(color: AppColors.slate400, fontSize: 13)),
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
    return switch (estado) {
      'aprobado' => const DsBadge(text: 'Verificado', tone: BadgeTone.info, icon: Icons.verified_outlined),
      'rechazado' => const DsBadge(text: 'Rechazado', tone: BadgeTone.danger),
      _ => const DsBadge(text: 'Pendiente', tone: BadgeTone.warning),
    };
  }
}
