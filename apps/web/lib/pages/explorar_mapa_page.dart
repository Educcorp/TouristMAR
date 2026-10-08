import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../models/lugar.dart';
import '../models/visitor_profile.dart';
import '../navegacion/rutas.dart';
import '../services/experiencias_launcher.dart';
import '../services/favoritos_service.dart';
import '../services/lugares_service.dart';
import '../services/recorridos_service.dart';
import '../theme/app_theme.dart';
import '../utils/keyboard.dart';
import '../widgets/app_shell.dart';
import '../widgets/favorito_button.dart';
import '../widgets/lugar_preview_card.dart';
import '../widgets/mapa/mapa_lugares.dart';
import '../widgets/themed_builder.dart';
import '../widgets/user_avatar.dart';
import 'ruta_lugar_page.dart';

/// "Explorar mapa" del visitante: todos los lugares aprobados como pines por
/// categoría, con búsqueda, filtros y una tarjeta de resumen al tocar uno.
class ExplorarMapaPage extends StatefulWidget {
  final VisitorProfile profile;
  final LugaresService service;

  const ExplorarMapaPage({super.key, required this.profile, this.service = const LugaresService()});

  @override
  State<ExplorarMapaPage> createState() => _ExplorarMapaPageState();
}

class _ExplorarMapaPageState extends State<ExplorarMapaPage> {
  final _mapController = MapController();
  final _busqueda = TextEditingController();
  List<Lugar> _lugares = [];
  /// Recorridos 360° publicados (para el acceso "Ver en 360°" de la tarjeta).
  List<RecorridoPublico> _recorridos = const [];
  bool _cargando = true;
  final Set<CategoriaLugar> _categorias = {};
  bool _soloConRa = false;
  String? _seleccionadoId;

  @override
  void initState() {
    super.initState();
    _busqueda.addListener(() => setState(() {}));
    _cargar();
    // Para que los corazones salgan bien aunque se entre directo a /mapa.
    FavoritosService.instance.cargarIds();
  }

  @override
  void dispose() {
    _busqueda.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    final lugares = await widget.service.listarPublicos();
    if (!mounted) return;
    setState(() {
      _lugares = lugares;
      _cargando = false;
    });
    try {
      final recorridos = await RecorridosService().listPublicos();
      if (!mounted) return;
      setState(() {
        _recorridos = recorridos;
        // Recorridos con pin propio que no son de un lugar del mapa (FIME…).
        _lugares = [..._lugares, ...lugaresDeRecorridos(recorridos, _lugares)];
      });
    } catch (_) {
      // Sin recorridos: la tarjeta simplemente no muestra el acceso 360°.
    }
  }

  RecorridoPublico? _recorridoDe(Lugar lugar) {
    final r = recorridoDeLugar(_recorridos, lugarId: lugar.id, lugarNombre: lugar.nombre);
    return r == null || r.escenas.isEmpty ? null : r;
  }

  /// Como en Google Maps: del pin directo al recorrido. En el teléfono con
  /// Unity lo abre Unity; en la web, el visor de Flutter.
  Future<void> _ver360(Lugar lugar) async {
    try {
      await ExperienciasLauncher.current.abrir(context, lugar, ExperienciaTipo.recorrido360);
    } on ExperienciaError catch (e) {
      _aviso(e.mensaje);
    } on ExperienciaNoConfigurada {
      _aviso('El recorrido 360° estará disponible muy pronto.');
    }
  }

  /// La ruta se ve en nuestro propio mapa (no se sale a Google Maps).
  Future<void> _comoLlegar(Lugar lugar) => abrirRutaEnMapa(context, lugar);

  void _aviso(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  List<Lugar> get _filtrados {
    final q = _busqueda.text.trim().toLowerCase();
    return _lugares.where((l) {
      if (_categorias.isNotEmpty && !_categorias.contains(l.categoria)) return false;
      if (_soloConRa && !l.tieneExperiencias) return false;
      if (q.isNotEmpty && !l.nombre.toLowerCase().contains(q) && !l.categoriaTexto.toLowerCase().contains(q)) {
        return false;
      }
      return true;
    }).toList();
  }

  Lugar? get _seleccionado {
    for (final l in _lugares) {
      if (l.id == _seleccionadoId) return l;
    }
    return null;
  }

  void _seleccionar(Lugar lugar) {
    setState(() => _seleccionadoId = lugar.id);
    if (lugar.ubicacion != null) {
      _mapController.move(toLatLng(lugar.ubicacion!), _mapController.camera.zoom < 14 ? 14 : _mapController.camera.zoom);
    }
  }

  void _abrirFicha(Lugar lugar) {
    abrirLugar(context, lugar);
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
      navItems: visitorNavItems(context, profile: profile, current: VisitorSection.mapa),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final ancho = constraints.maxWidth >= 900;
          return ancho
              ? Row(
                  children: [
                    SizedBox(width: 360, child: _panelLista()),
                    Expanded(child: _mapa(compacto: false)),
                  ],
                )
              : _mapa(compacto: true);
        },
      ),
    );
  }

  /// Alto reservado abajo del mapa para la franja de créditos de
  /// OpenStreetMap, más un margen.
  static const _margenInferior = 44.0;

  Widget _mapa({required bool compacto}) {
    final filtrados = _filtrados;
    final seleccionado = _seleccionado;

    return Stack(
      children: [
        Positioned.fill(
          child: MapaBase(
            controller: _mapController,
            onTap: (_) => setState(() => _seleccionadoId = null),
            children: [capaLugares(filtrados, seleccionadoId: _seleccionadoId, onTap: _seleccionar)],
          ),
        ),
        if (compacto)
          Positioned(
            left: 12,
            right: 12,
            top: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CampoBusqueda(controller: _busqueda, flotante: true),
                const SizedBox(height: AppSpacing.sm),
                SizedBox(height: 36, child: _filtros(scroll: true)),
              ],
            ),
          ),
        // Los controles y el aviso de datos de ejemplo van por encima de la
        // franja de créditos de OpenStreetMap (abajo del mapa); antes estaban
        // a 24 px del borde y tapaban el texto del copyright.
        Positioned(
          right: 12,
          bottom: compacto && seleccionado != null ? 200 : _margenInferior,
          child: ControlesMapa(controller: _mapController),
        ),
        if (widget.service.usaDatosDemo)
          Positioned(
            left: 12,
            bottom: compacto ? (seleccionado != null ? 200 : _margenInferior + 64) : _margenInferior,
            child: const _AvisoDemo(),
          ),
        if (_cargando) const Center(child: CircularProgressIndicator()),
        if (compacto && seleccionado == null && !_cargando)
          Positioned(
            left: 0,
            right: 0,
            bottom: _margenInferior + 8,
            child: Center(
              child: FilledButton.icon(
                onPressed: _abrirLista,
                icon: const Icon(Icons.view_list_rounded),
                label: Text('Ver lista (${filtrados.length})'),
              ),
            ),
          ),
        if (seleccionado != null)
          Positioned(
            left: 12,
            right: compacto ? 12 : null,
            top: compacto ? null : 16,
            bottom: compacto ? 12 : null,
            width: compacto ? null : 320,
            child: LugarPreviewCard(
              lugar: seleccionado,
              compacta: compacto,
              onCerrar: () => setState(() => _seleccionadoId = null),
              onVerFicha: () => _abrirFicha(seleccionado),
              recorrido360: _recorridoDe(seleccionado),
              onVer360: () => _ver360(seleccionado),
              onComoLlegar: seleccionado.ubicacion == null ? null : () => _comoLlegar(seleccionado),
            ),
          ),
      ],
    );
  }

  Widget _panelLista() {
    final filtrados = _filtrados;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.panelNavy,
        border: Border(right: BorderSide(color: AppColors.overlay(0.08))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Explorar Manzanillo', style: AppTypography.h2),
                const SizedBox(height: 4),
                Text('Toca un punto para ver su ficha y experiencias.', style: AppTypography.bodySmall),
                const SizedBox(height: AppSpacing.lg),
                _CampoBusqueda(controller: _busqueda),
                const SizedBox(height: AppSpacing.md),
                _filtros(scroll: false),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text('${filtrados.length} lugares', style: AppTypography.caption),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
              itemCount: filtrados.length,
              separatorBuilder: (_, __) => const SizedBox(height: 4),
              itemBuilder: (context, i) => _filaLugar(filtrados[i]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filaLugar(Lugar l, {VoidCallback? alElegir}) {
    final activo = l.id == _seleccionadoId;
    final cat = l.categoria;
    return Material(
      color: activo ? AppColors.surfaceAlt : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.buttonLg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.buttonLg),
        onTap: () {
          alElegir?.call();
          _seleccionar(l);
        },
        onDoubleTap: () => _abrirFicha(l),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: cat.esmalte, borderRadius: BorderRadius.circular(8)),
                child: Icon(cat.icon, size: 22, color: cat.esmalte.computeLuminance() < 0.3 ? Colors.white : AppColors.riel),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.nombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 2),
                    Text(
                      l.tieneExperiencias
                          ? '${cat.etiqueta} · ${l.totalExperiencias} experiencia${l.totalExperiencias == 1 ? '' : 's'}'
                          : cat.etiqueta,
                      style: AppTypography.bodySmall,
                    ),
                  ],
                ),
              ),
              if (l.totalResenas > 0) ...[
                const Icon(Icons.star_rounded, size: 18, color: AppColors.amarillo),
                const SizedBox(width: 2),
                Text(l.rating.toStringAsFixed(1),
                    style: TextStyle(color: AppColors.tinta, fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(width: 4),
              ],
              if (l.esFavoritable) FavoritoButton(lugar: l, sobreFoto: false, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  /// En móvil la lista vive en una hoja que sube desde abajo.
  void _abrirLista() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (hoja) {
        final filtrados = _filtrados;
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.92,
          builder: (context, scroll) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text('${filtrados.length} lugares', style: AppTypography.h2),
              ),
              Expanded(
                child: ListView.separated(
                  controller: scroll,
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                  itemCount: filtrados.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (context, i) => _filaLugar(filtrados[i], alElegir: () => Navigator.of(hoja).pop()),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _filtros({required bool scroll}) {
    final chips = <Widget>[
      _ChipFiltro(
        label: 'Con RA / 360°',
        icon: Icons.view_in_ar_outlined,
        color: AppColors.riel,
        activo: _soloConRa,
        onTap: () => setState(() => _soloConRa = !_soloConRa),
      ),
      for (final c in CategoriaLugar.values.where((c) => _lugares.any((l) => l.categoria == c)))
        _ChipFiltro(
          label: c.etiqueta,
          icon: c.icon,
          color: c.esmalte,
          activo: _categorias.contains(c),
          onTap: () => setState(() => _categorias.contains(c) ? _categorias.remove(c) : _categorias.add(c)),
        ),
    ];

    if (!scroll) return Wrap(spacing: 6, runSpacing: 6, children: chips);
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: chips.length,
      separatorBuilder: (_, __) => const SizedBox(width: 6),
      itemBuilder: (_, i) => chips[i],
    );
  }
}

class _CampoBusqueda extends StatelessWidget {
  final TextEditingController controller;
  final bool flotante;

  const _CampoBusqueda({required this.controller, this.flotante = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.panelNavySoft,
        borderRadius: BorderRadius.circular(AppRadius.buttonLg),
        border: Border.all(color: AppColors.overlay(0.1)),
        boxShadow: flotante
            ? [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 14, offset: const Offset(0, 4))]
            : null,
      ),
      child: Row(
        children: [
          Icon(Icons.search, size: 18, color: AppColors.slate500),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              // Tocar fuera de la barra cierra el teclado (en Android, por
              // defecto, un toque fuera no le quita el foco al campo).
              onTapOutside: (_) => hideKeyboard(),
              style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 13),
                hintText: 'Buscar playas, restaurantes, miradores…',
                hintStyle: TextStyle(color: AppColors.slate500),
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            InkWell(
              onTap: controller.clear,
              child: Icon(Icons.close, size: 16, color: AppColors.slate400),
            ),
        ],
      ),
    );
  }
}

class _ChipFiltro extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool activo;
  final VoidCallback onTap;

  const _ChipFiltro({
    required this.label,
    required this.icon,
    required this.color,
    required this.activo,
    required this.onTap,
  });

  /// Texto sobre el esmalte: blanco en los oscuros, tinta en los claros.
  Color get _sobre => color.computeLuminance() < 0.3 ? Colors.white : AppColors.riel;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: activo ? color : AppColors.panelNavySoft,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: activo ? color : AppColors.overlay(0.12)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: activo ? _sobre : AppColors.tinta),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(color: activo ? _sobre : AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvisoDemo extends StatelessWidget {
  const _AvisoDemo();

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Los puntos son de ejemplo hasta que el backend guarde la ubicación de cada negocio.',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.amarillo,
          borderRadius: BorderRadius.circular(4),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8)],
        ),
        child: Text('DATOS DE EJEMPLO', style: AppTypography.matricula(size: 14, color: AppColors.riel)),
      ),
    );
  }
}
