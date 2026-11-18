import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/lugar.dart';
import '../../navegacion/rutas.dart';
import '../../services/auth_service.dart' show AuthError;
import '../../services/ra_geo_service.dart';
import '../../services/session_storage.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin/ds_badge.dart';
import '../../widgets/admin/ds_button.dart';
import '../../widgets/admin/ds_card.dart';
import '../../widgets/admin/ds_states.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/aviso.dart';

/// Sección "Historias de RA" del panel admin (`/admin/historias`): el texto
/// que lee el visitante en la RA por geolocalización de cada lugar, sin
/// entrar a la ficha del lugar ni tocar Unity.
///
/// Edita los mismos puntos de interés que "Lugares y experiencias" → ficha →
/// "RA por geolocalización" (tabla ra_geo_puntos): el resumen (se lee desde
/// lejos, en el marcador flotante) y la historia (la guía completa que se
/// abre al llegar). Si el lugar todavía no tiene puntos, al guardar se crea
/// uno en su pin, con los radios por defecto.
class AdminHistoriasRaPage extends StatefulWidget {
  final RaGeoService service;

  AdminHistoriasRaPage({super.key, RaGeoService? service}) : service = service ?? RaGeoService();

  @override
  State<AdminHistoriasRaPage> createState() => _AdminHistoriasRaPageState();
}

class _AdminHistoriasRaPageState extends State<AdminHistoriasRaPage> {
  static final _color = ExperienciaInfo.of(ExperienciaTipo.arGeo).color;

  List<LugarConHistoria>? _lugares;
  String? _error;
  String _buscar = '';
  String? _abierto;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _error = null);
    try {
      final lugares = await widget.service.lugaresPublicos();
      lugares.sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
      if (mounted) setState(() => _lugares = lugares);
    } catch (err) {
      if (mounted) setState(() => _error = err is AuthError ? err.message : 'No se pudieron cargar los lugares');
    }
  }

  static String _normalizar(String s) {
    const de = 'áéíóúüñÁÉÍÓÚÜÑ';
    const a = 'aeiouunaeiouun';
    final b = StringBuffer();
    for (final c in s.toLowerCase().split('')) {
      final i = de.indexOf(c);
      b.write(i >= 0 ? a[i] : c);
    }
    return b.toString();
  }

  @override
  Widget build(BuildContext context) {
    final lugares = _lugares;
    final filtrados = lugares == null
        ? const <LugarConHistoria>[]
        : lugares
            .where((l) => _buscar.isEmpty || _normalizar('${l.nombre} ${l.categoria}').contains(_normalizar(_buscar)))
            .toList();
    final conHistoria = lugares?.where((l) => l.tieneHistoria).length ?? 0;

    return RefreshIndicator(
      onRefresh: _cargar,
      color: _color,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Historias de RA', style: AppTypography.h1),
              const SizedBox(height: 4),
              Text(
                lugares == null
                    ? 'Lo que lee el visitante en la RA por geolocalización de cada lugar.'
                    : '${lugares.length} lugares con ubicación · $conHistoria con historia',
                style: AppTypography.body,
              ),
              const SizedBox(height: 2),
              Text(
                'El resumen se lee desde lejos en la cámara; la historia se abre al llegar al lugar. '
                'La app la muestra la próxima vez que se abra la RA.',
                style: AppTypography.bodySmall,
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                onChanged: (v) => setState(() => _buscar = v.trim()),
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.search, color: AppColors.slate400),
                  hintText: 'Buscar lugar o categoría',
                  hintStyle: TextStyle(color: AppColors.slate400),
                  filled: true,
                  fillColor: AppColors.cubierta,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.button),
                    borderSide: BorderSide(color: AppColors.borderSubtle),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.button),
                    borderSide: BorderSide(color: AppColors.borderSubtle),
                  ),
                ),
                style: TextStyle(color: AppColors.textPrimary),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (_error != null)
                DsErrorState(message: _error!, onRetry: _cargar)
              else if (lugares == null)
                DsLoadingState(accent: _color)
              else if (lugares.isEmpty)
                const DsEmptyState(
                  icon: Icons.location_off_outlined,
                  title: 'Ningún lugar tiene ubicación',
                  subtitle: 'Pon el pin de un lugar en "Lugares y experiencias" para escribir su historia.',
                )
              else if (filtrados.isEmpty)
                DsEmptyState(icon: Icons.search_off, title: 'Sin resultados', subtitle: 'Nada coincide con "$_buscar".')
              else
                for (final l in filtrados) ...[
                  _TarjetaLugar(
                    key: ValueKey(l.id),
                    lugar: l,
                    abierto: _abierto == l.id,
                    color: _color,
                    service: widget.service,
                    onAlternar: () => setState(() => _abierto = _abierto == l.id ? null : l.id),
                    onGuardado: _cargar,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Un lugar de la lista: nombre, estado y, abierto, el editor de sus textos.
class _TarjetaLugar extends StatefulWidget {
  final LugarConHistoria lugar;
  final bool abierto;
  final Color color;
  final RaGeoService service;
  final VoidCallback onAlternar;
  final Future<void> Function() onGuardado;

  const _TarjetaLugar({
    super.key,
    required this.lugar,
    required this.abierto,
    required this.color,
    required this.service,
    required this.onAlternar,
    required this.onGuardado,
  });

  @override
  State<_TarjetaLugar> createState() => _TarjetaLugarState();
}

class _TarjetaLugarState extends State<_TarjetaLugar> {
  /// Puntos del admin (incluye los ocultos). null = aún no se cargan.
  List<PuntoRaGeo>? _puntos;
  String? _error;

  @override
  void didUpdateWidget(_TarjetaLugar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.abierto && !oldWidget.abierto) _cargar();
  }

  @override
  void initState() {
    super.initState();
    if (widget.abierto) _cargar();
  }

  Future<void> _cargar() async {
    final token = SessionStorage.token;
    if (token == null) return;
    setState(() {
      _puntos = null;
      _error = null;
    });
    try {
      final puntos = await widget.service.listar(token, widget.lugar.id);
      if (mounted) setState(() => _puntos = puntos);
    } catch (err) {
      if (mounted) setState(() => _error = err is AuthError ? err.message : 'No se pudieron cargar los textos');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.lugar;
    final (texto, tono) = l.tieneHistoria
        ? ('Con historia', BadgeTone.success)
        : l.tienePuntos
            ? ('Sin historia', BadgeTone.warning)
            : ('Sin textos', BadgeTone.neutral);

    return DsCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(AppRadius.card),
            onTap: widget.onAlternar,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Icon(Icons.place_outlined, color: widget.color),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.nombre, style: AppTypography.h3.copyWith(fontSize: 15)),
                        if (l.categoria.isNotEmpty) Text(l.categoria, style: AppTypography.bodySmall),
                      ],
                    ),
                  ),
                  DsBadge(text: texto, tone: tono),
                  const SizedBox(width: AppSpacing.sm),
                  Icon(widget.abierto ? Icons.expand_less : Icons.expand_more, color: AppColors.slate400),
                ],
              ),
            ),
          ),
          if (widget.abierto)
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
              child: _contenido(),
            ),
        ],
      ),
    );
  }

  Widget _contenido() {
    if (_error != null) return DsErrorState(message: _error!, onRetry: _cargar);
    final puntos = _puntos;
    if (puntos == null) return DsLoadingState(accent: widget.color);
    final l = widget.lugar;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (puntos.isEmpty)
          _EditorHistoria(
            key: const ValueKey('nuevo'),
            titulo: l.nombre,
            subtitulo: 'Todavía no tiene textos: al guardar se crea un punto en el pin del lugar.',
            color: widget.color,
            onGuardar: (resumen, detalle) async {
              final token = SessionStorage.token;
              if (token == null) return;
              await widget.service.crear(
                token,
                l.id,
                PuntoRaGeo(titulo: l.nombre, resumen: resumen, detalle: detalle, ubicacion: l.ubicacion),
              );
              await _cargar();
              await widget.onGuardado();
            },
          )
        else
          for (final (i, p) in puntos.indexed) ...[
            if (i > 0) const SizedBox(height: AppSpacing.md),
            _EditorHistoria(
              key: ValueKey(p.id),
              titulo: puntos.length > 1 ? '${i + 1}. ${p.titulo}' : p.titulo,
              subtitulo: p.activo ? null : 'Punto oculto: no se ve en la app.',
              resumen: p.resumen,
              detalle: p.detalle,
              color: widget.color,
              onGuardar: (resumen, detalle) async {
                final token = SessionStorage.token;
                if (token == null) return;
                await widget.service.actualizar(token, p.id!, {'resumen': resumen, 'detalle': detalle});
                await _cargar();
                await widget.onGuardado();
              },
            ),
          ],
        const SizedBox(height: AppSpacing.sm),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => context.go(rutaLugarAdmin(l.id)),
            icon: Icon(Icons.open_in_new, size: 16, color: widget.color),
            label: Text(
              'Puntos, radios, imagen y audio: en la ficha del lugar',
              style: TextStyle(color: widget.color),
            ),
          ),
        ),
      ],
    );
  }
}

/// Resumen + historia de un punto, con su botón de guardar.
class _EditorHistoria extends StatefulWidget {
  final String titulo;
  final String? subtitulo;
  final String resumen;
  final String detalle;
  final Color color;
  final Future<void> Function(String resumen, String detalle) onGuardar;

  const _EditorHistoria({
    super.key,
    required this.titulo,
    this.subtitulo,
    this.resumen = '',
    this.detalle = '',
    required this.color,
    required this.onGuardar,
  });

  @override
  State<_EditorHistoria> createState() => _EditorHistoriaState();
}

class _EditorHistoriaState extends State<_EditorHistoria> {
  final _form = GlobalKey<FormState>();
  late final _resumen = TextEditingController(text: widget.resumen);
  late final _detalle = TextEditingController(text: widget.detalle);
  bool _guardando = false;

  @override
  void dispose() {
    _resumen.dispose();
    _detalle.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _guardando = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.onGuardar(_resumen.text.trim(), _detalle.text.trim());
      messenger.showSnackBar(aviso('Historia guardada'));
    } catch (err) {
      messenger.showSnackBar(
        aviso(err is AuthError ? err.message : 'No se pudo guardar la historia', tipo: AvisoTipo.error),
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: widget.color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.titulo, style: AppTypography.h3.copyWith(fontSize: 14)),
            if (widget.subtitulo != null) ...[
              const SizedBox(height: 2),
              Text(widget.subtitulo!, style: AppTypography.bodySmall),
            ],
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Resumen (una o dos líneas, se lee desde lejos)',
              icon: Icons.short_text,
              controller: _resumen,
              hintText: 'Ej. Playa de arena fina y oleaje suave en la Bahía de Manzanillo',
              accentColor: widget.color,
              validator: (v) => (v?.trim().length ?? 0) > 200 ? 'Máximo 200 caracteres' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Historia (se abre al llegar al lugar)',
              icon: Icons.menu_book_outlined,
              controller: _detalle,
              maxLines: 7,
              hintText: 'Historia del lugar, qué hay aquí, datos curiosos, recomendaciones…',
              accentColor: widget.color,
              validator: (v) => (v?.trim().length ?? 0) > 4000 ? 'Máximo 4000 caracteres' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerRight,
              child: DsButton(
                label: _guardando ? 'Guardando…' : 'Guardar historia',
                icon: Icons.save_outlined,
                variant: DsButtonVariant.primary,
                accent: widget.color,
                onPressed: _guardando ? null : _guardar,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
