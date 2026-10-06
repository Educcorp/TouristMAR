import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/lugar.dart';
import '../../navegacion/rutas.dart';
import '../../services/auth_service.dart';
import '../../services/session_storage.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin/admin_shell.dart';
import '../../widgets/admin/ds_button.dart';
import '../../widgets/admin/ds_states.dart';
import '../../widgets/admin/seccion_desplegable.dart';
import 'admin_lugar_widgets.dart';
import 'admin_recorridos_page.dart';

/// Un lugar dentro de "Mapa y RA" (`/admin/mapa/lugar/<id>`): sus datos y
/// sus tres experiencias como secciones que se despliegan con una flecha, cada
/// una con su formulario (coordenadas y pin, recorrido 360° con sus escenarios,
/// marcadores de RA).
class AdminLugarPage extends StatefulWidget {
  final String lugarId;
  final AuthService authService;

  AdminLugarPage({super.key, required this.lugarId, AuthService? authService})
      : authService = authService ?? AuthService();

  @override
  State<AdminLugarPage> createState() => _AdminLugarPageState();
}

class _AdminLugarPageState extends State<AdminLugarPage> {
  NegocioSummary? _lugar;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final token = SessionStorage.token;
    if (token == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final lista = await widget.authService.adminListNegocios(token);
      if (!mounted) return;
      final lugar = lista.where((n) => n.id == widget.lugarId).firstOrNull;
      setState(() {
        _lugar = lugar;
        if (lugar == null) _error = 'Este lugar ya no existe.';
      });
    } catch (err) {
      if (mounted) setState(() => _error = err is AuthError ? err.message : 'No se pudo conectar con el servidor');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _volver() => context.go(rutaAdmin(AdminSection.mapa));

  /// Lo que ve el visitante: la ficha del lugar en vista previa.
  void _verFicha(NegocioSummary n) {
    abrirLugar(
      context,
      Lugar(
        id: n.id,
        nombre: n.nombre,
        categoriaTexto: n.categoria ?? '',
        descripcion: n.descripcion ?? '',
        direccion: n.direccion,
        portada: 'assets/images/hero-manzanillo.jpg',
        ubicacion: coordenadasDe(n),
      ),
      vistaPrevia: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Arriba a la izquierda aunque haya poco contenido (el panel centra lo
    // que no ocupa toda la altura).
    return Align(
      alignment: Alignment.topLeft,
      child: _contenidoConScroll(),
    );
  }

  Widget _contenidoConScroll() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1320),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextButton.icon(
              onPressed: _volver,
              icon: Icon(Icons.arrow_back, size: 16, color: AppColors.slate300),
              label: Text('Mapa y RA', style: TextStyle(color: AppColors.slate300)),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (_loading)
              DsLoadingState(accent: AppColors.adminViolet)
            else if (_lugar == null)
              DsErrorState(message: _error ?? 'Este lugar ya no existe.', onRetry: _cargar)
            else
              ..._contenido(_lugar!),
          ],
        ),
      ),
    );
  }

  List<Widget> _contenido(NegocioSummary n) {
    final pin = coordenadasDe(n);
    final geo = ExperienciaInfo.of(ExperienciaTipo.arGeo);
    final r360 = ExperienciaInfo.of(ExperienciaTipo.recorrido360);
    final marcador = ExperienciaInfo.of(ExperienciaTipo.arMarcador);
    return [
      Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.lg,
        runSpacing: AppSpacing.md,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(n.nombre, style: AppTypography.h1),
              const SizedBox(height: 4),
              Text(
                [
                  n.categoria ?? 'Sin categoría',
                  if (n.direccion?.isNotEmpty ?? false) n.direccion!,
                  pin == null ? 'Sin coordenadas' : '$pin',
                ].join(' · '),
                style: AppTypography.body,
              ),
            ],
          ),
          DsButton(
            label: 'Ver ficha',
            icon: Icons.visibility_outlined,
            variant: DsButtonVariant.ghost,
            onPressed: () => _verFicha(n),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.xl),
      SeccionDesplegable(
        key: const ValueKey('datos'),
        icon: Icons.edit_location_alt_outlined,
        titulo: 'Datos del lugar',
        child: LugarForm(
          lugar: n,
          authService: widget.authService,
          onGuardado: (g) {
            setState(() => _lugar = g);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lugar guardado')));
          },
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      SeccionDesplegable(
        key: const ValueKey('geo'),
        icon: geo.icon,
        color: geo.color,
        titulo: geo.titulo,
        subtitulo: pin == null ? null : 'Pin: $pin',
        child: UbicacionLugarSection(
          key: ValueKey('geo-${n.latitud}-${n.longitud}'),
          lugar: n,
          authService: widget.authService,
          onGuardado: (g) => setState(() => _lugar = g),
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      SeccionDesplegable(
        key: const ValueKey('360'),
        icon: r360.icon,
        color: r360.color,
        titulo: r360.titulo,
        child: RecorridosLugarSection(lugar: n),
      ),
      const SizedBox(height: AppSpacing.md),
      SeccionDesplegable(
        key: const ValueKey('marcador'),
        icon: marcador.icon,
        color: marcador.color,
        titulo: marcador.titulo,
        child: MarcadoresLugarSection(lugar: n),
      ),
    ];
  }
}
