import 'package:flutter/material.dart';

import '../models/business_profile.dart';
import '../models/lugar.dart';
import '../navegacion/rutas.dart';
import '../services/auth_service.dart' show AuthError;
import '../services/lugares_service.dart';
import '../services/recorridos_service.dart';
import '../theme/app_theme.dart';
import '../widgets/admin/ds_badge.dart';
import '../widgets/admin/ds_button.dart';
import '../widgets/admin/ds_card.dart';
import '../widgets/experiencias/experiencia_viewport.dart';
import '../widgets/experiencias/experiencias_lugar.dart';
import '../widgets/mapa/mapa_lugares.dart';
import '../widgets/aviso.dart';

/// Sección "Mapa y experiencias" del panel de empresa: el negocio fija su
/// punto en el mapa, sube los recursos de sus tres experiencias y ve cómo
/// quedarán para el visitante. Embebido en [BusinessShell].
class BusinessExperienciasContent extends StatefulWidget {
  final BusinessProfile business;
  final LugaresService service;
  final RecorridosService? recorridosService;

  const BusinessExperienciasContent({
    super.key,
    required this.business,
    this.service = const LugaresService(),
    this.recorridosService,
  });

  @override
  State<BusinessExperienciasContent> createState() => _BusinessExperienciasContentState();
}

class _BusinessExperienciasContentState extends State<BusinessExperienciasContent> {
  Coordenadas? _ubicacion;
  bool _guardando = false;

  /// Recorridos 360° publicados para este negocio (los sube un admin en
  /// "Recorridos 360°"; el endpoint público solo lista los de negocios
  /// aprobados). null = cargando o sin conexión.
  List<RecorridoPublico>? _recorridos;

  BusinessProfile get _b => widget.business;

  @override
  void initState() {
    super.initState();
    if (_b.latitud != null && _b.longitud != null) _ubicacion = Coordenadas(_b.latitud!, _b.longitud!);
    _cargarRecorridos();
  }

  Future<void> _cargarRecorridos() async {
    try {
      final lista = await (widget.recorridosService ?? RecorridosService()).listPublicos(negocioId: _b.id);
      if (mounted) setState(() => _recorridos = lista);
    } catch (_) {
      // Sin conexión: la tarjeta 360° solo muestra la información general.
    }
  }

  Lugar get _lugar => Lugar(
        id: _b.id,
        nombre: _b.businessName,
        categoriaTexto: _b.category,
        descripcion: _b.description,
        direccion: _b.address,
        horario: _b.hours,
        telefono: _b.phone,
        portada: _b.coverImage,
        galeria: _b.gallery,
        rating: _b.rating,
        totalResenas: _b.totalReviews,
        ubicacion: _ubicacion,
        // La vista previa solo necesita saber si hay recorrido publicado.
        archivo360: (_recorridos?.isNotEmpty ?? false) ? _recorridos!.first.urlPortada : null,
        arMarcador: _b.arMarcador,
        arGeo: _b.arGeo,
      );

  Future<void> _ejecutar(Future<void> Function() accion) async {
    setState(() => _guardando = true);
    try {
      await accion();
    } on AuthError catch (e) {
      if (mounted) _aviso(e.message);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  void _aviso(String texto) => ScaffoldMessenger.of(context).showSnackBar(aviso(texto));


  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Mapa y experiencias', style: AppTypography.h1),
                const SizedBox(height: 4),
                Text(
                  'Ubica tu negocio en el mapa y prepara las experiencias que verán tus visitantes.',
                  style: AppTypography.body,
                ),
                if (!_b.verified) ...[
                  const SizedBox(height: AppSpacing.lg),
                  _Aviso(
                    icon: Icons.hourglass_top,
                    color: AppColors.amber,
                    texto: 'Tu negocio está en revisión. Puedes prepararlo todo; se publicará en el mapa cuando un administrador lo apruebe.',
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                _buildUbicacion(),
                const SizedBox(height: AppSpacing.xl),
                Text('Experiencias inmersivas', style: AppTypography.h2),
                const SizedBox(height: 4),
                Text(
                  'Las experiencias las activa la administración de TouristMAR. Aquí ves cuáles '
                  'tiene tu negocio; las que no estén activas aparecen como "no disponible" para los visitantes.',
                  style: AppTypography.bodySmall,
                ),
                const SizedBox(height: AppSpacing.md),
                for (final tipo in ExperienciaTipo.values) ...[
                  _RecursoCard(
                    tipo: tipo,
                    activa: _lugar.tiene(tipo),
                    publicada: _b.verified,
                    extra: tipo == ExperienciaTipo.recorrido360 ? _buildRecorridos() : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                const SizedBox(height: AppSpacing.lg),
                _buildVistaPrevia(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUbicacion() {
    return DsCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                Icon(Icons.pin_drop_outlined, color: AppColors.businessOrange),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Ubicación en el mapa', style: AppTypography.h3),
                      Text(
                        _ubicacion == null
                            ? 'Toca el mapa en la entrada de tu negocio para colocar el punto.'
                            : 'Punto: $_ubicacion — toca otra parte del mapa para moverlo.',
                        style: AppTypography.bodySmall,
                      ),
                    ],
                  ),
                ),
                DsBadge(
                  text: _ubicacion == null ? 'Sin ubicar' : 'Sin guardar',
                  tone: _ubicacion == null ? BadgeTone.neutral : BadgeTone.warning,
                ),
              ],
            ),
          ),
          SizedBox(
            height: 320,
            child: Stack(
              children: [
                Positioned.fill(
                  child: MapaBase(
                    zoom: 13,
                    onTap: (p) => setState(() => _ubicacion = p),
                    children: [
                      if (_ubicacion != null) capaLugares([_lugar], seleccionadoId: _b.id),
                    ],
                  ),
                ),
                if (_ubicacion == null)
                  IgnorePointer(
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.scrimDark.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.touch_app_outlined, size: 16, color: Colors.white),
                            SizedBox(width: 6),
                            Text('Toca para colocar tu negocio',
                                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              alignment: WrapAlignment.end,
              children: [
                if (_ubicacion != null)
                  DsButton(
                    label: 'Quitar punto',
                    icon: Icons.close,
                    variant: DsButtonVariant.ghost,
                    onPressed: () => setState(() => _ubicacion = null),
                  ),
                DsButton(
                  label: 'Guardar ubicación',
                  icon: Icons.check,
                  variant: DsButtonVariant.primary,
                  accent: AppColors.businessOrange,
                  onPressed: _ubicacion == null || _guardando
                      ? null
                      : () => _ejecutar(() async {
                            await widget.service.guardarUbicacion(_b.id, _ubicacion!);
                            _b
                              ..latitud = _ubicacion!.lat
                              ..longitud = _ubicacion!.lng;
                            if (mounted) _aviso('Ubicación guardada: así aparece tu negocio en el mapa.');
                          }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecorridos() {
    final lista = _recorridos;
    if (lista == null) return const SizedBox.shrink();
    if (lista.isEmpty) {
      return Text('Tu negocio todavía no tiene recorridos 360° publicados.', style: AppTypography.caption);
    }
    final info = ExperienciaInfo.of(ExperienciaTipo.recorrido360);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final r in lista)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Icon(Icons.check_circle, size: 14, color: info.color),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    '${r.titulo} · ${r.escenas.length} ${r.escenas.length == 1 ? 'escenario' : 'escenarios'} 360°',
                    style: AppTypography.body.copyWith(fontSize: 12, color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildVistaPrevia() {
    return DsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.visibility_outlined, color: AppColors.businessOrange),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: Text('Así lo verán los visitantes', style: AppTypography.h3)),
              DsButton(
                label: 'Ver ficha completa',
                icon: Icons.open_in_new,
                size: DsButtonSize.sm,
                accent: AppColors.businessOrange,
                onPressed: () => abrirLugar(context, _lugar, vistaPrevia: true),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          ExperienciasLugarSection(lugar: _lugar, vistaPrevia: true),
        ],
      ),
    );
  }
}

/// Estado de una experiencia del negocio: si está activa o no y quién la
/// activa. El negocio no sube archivos: los marcadores, la RA por ubicación y
/// los recorridos 360° los da de alta la administración.
class _RecursoCard extends StatelessWidget {
  final ExperienciaTipo tipo;
  final bool activa;

  /// El negocio ya está aprobado (si no, nada se ve todavía en el mapa).
  final bool publicada;
  final Widget? extra;

  const _RecursoCard({required this.tipo, required this.activa, required this.publicada, this.extra});

  static String comoSeActiva(ExperienciaTipo tipo) => switch (tipo) {
        ExperienciaTipo.arMarcador =>
          'La administración da de alta la imagen que reconoce la cámara y la información que aparece encima. '
              'Si quieres una para tu negocio, pídela a un administrador.',
        ExperienciaTipo.arGeo =>
          'La administración coloca los puntos de RA alrededor de tu negocio. Tu negocio necesita tener '
              'su ubicación guardada en el mapa.',
        ExperienciaTipo.recorrido360 =>
          'La administración sube los escenarios 360° de tu negocio. Puedes solicitar uno desde "Mi negocio".',
      };

  @override
  Widget build(BuildContext context) {
    final info = ExperienciaInfo.of(tipo);
    final (badgeText, tone) = !activa
        ? ('No activa', BadgeTone.neutral)
        : (publicada ? ('Activa', BadgeTone.success) : ('Activa · en revisión', BadgeTone.warning));

    return DsCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final ancho = constraints.maxWidth >= 640;
          final visor = SizedBox(
            width: ancho ? 220 : double.infinity,
            child: ExperienciaViewport(
              tipo: tipo,
              aspectRatio: 4 / 3,
              mensaje: activa ? 'Disponible para los visitantes' : 'Todavía no activa',
            ),
          );

          final detalle = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(info.icon, size: 18, color: info.color),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text(info.titulo, style: AppTypography.h3)),
                  DsBadge(text: badgeText, tone: tone),
                ],
              ),
              const SizedBox(height: 4),
              Text(info.descripcion, style: AppTypography.bodySmall),
              const SizedBox(height: AppSpacing.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.admin_panel_settings_outlined, size: 16, color: AppColors.slate400),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text(comoSeActiva(tipo), style: AppTypography.body.copyWith(fontSize: 12))),
                ],
              ),
              if (extra != null) ...[
                const SizedBox(height: AppSpacing.md),
                extra!,
              ],
            ],
          );

          if (!ancho) {
            return Column(children: [visor, const SizedBox(height: AppSpacing.lg), detalle]);
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [visor, const SizedBox(width: AppSpacing.lg), Expanded(child: detalle)],
          );
        },
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String texto;

  const _Aviso({required this.icon, required this.color, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.buttonLg),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(texto, style: AppTypography.body.copyWith(color: AppColors.textPrimary, fontSize: 13))),
        ],
      ),
    );
  }
}
