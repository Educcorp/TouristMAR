import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../models/lugar.dart';
import '../../services/auth_service.dart';
import '../../services/experiencias_launcher.dart' show formatoDistancia;
import '../../services/ra_geo_service.dart';
import '../../services/session_storage.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin/ds_button.dart';
import '../../widgets/admin/ds_states.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/mapa/mapa_lugares.dart';
import '../../widgets/mapa/ubicacion_lugar.dart';
import 'admin_lugar_widgets.dart' show coordenadasDe;

// "RA por geolocalización" de un lugar en "Mapa y RA": sus puntos de
// interés, cada uno con dos radios (marcador flotante y guía completa).

String _mensaje(Object err, String porDefecto) => err is AuthError ? err.message : porDefecto;

/// Puntos de interés de la RA por geolocalización del lugar: mapa con sus
/// dos círculos, lista y formulario para agregar o editar.
class PuntosRaGeoSection extends StatefulWidget {
  final NegocioSummary lugar;
  final RaGeoService service;

  PuntosRaGeoSection({super.key, required this.lugar, RaGeoService? service}) : service = service ?? RaGeoService();

  @override
  State<PuntosRaGeoSection> createState() => _PuntosRaGeoSectionState();
}

class _PuntosRaGeoSectionState extends State<PuntosRaGeoSection> {
  List<PuntoRaGeo>? _puntos;
  String? _error;
  final Set<String> _ocupados = {};

  Color get _color => ExperienciaInfo.of(ExperienciaTipo.arGeo).color;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final token = SessionStorage.token;
    if (token == null) return;
    setState(() => _error = null);
    try {
      final puntos = await widget.service.listar(token, widget.lugar.id);
      if (mounted) setState(() => _puntos = puntos);
    } catch (err) {
      if (mounted) setState(() => _error = _mensaje(err, 'No se pudieron cargar los puntos'));
    }
  }

  void _aviso(String texto) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));

  Future<void> _editar([PuntoRaGeo? punto]) async {
    final guardado = await showDialog<PuntoRaGeo>(
      context: context,
      builder: (_) => _DialogoPunto(
        lugar: widget.lugar,
        punto: punto,
        numero: punto == null ? (_puntos?.length ?? 0) + 1 : (_puntos!.indexOf(punto) + 1),
        service: widget.service,
      ),
    );
    if (guardado == null || !mounted) return;
    await _cargar();
    _aviso(punto == null ? 'Punto agregado' : 'Punto guardado');
  }

  Future<void> _alternarActivo(PuntoRaGeo p, bool activo) => _accion(p, () async {
        final token = SessionStorage.token!;
        await widget.service.actualizar(token, p.id!, {'activo': activo});
      });

  Future<void> _borrar(PuntoRaGeo p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.panelNavySoft,
        title: Text('¿Borrar "${p.titulo}"?', style: AppTypography.h3),
        content: Text('Los visitantes dejarán de verlo en la cámara.', style: AppTypography.body),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          DsButton(label: 'Borrar', variant: DsButtonVariant.danger, onPressed: () => Navigator.of(context).pop(true)),
        ],
      ),
    );
    if (ok != true) return;
    await _accion(p, () => widget.service.borrar(SessionStorage.token!, p.id!));
  }

  Future<void> _accion(PuntoRaGeo p, Future<void> Function() fn) async {
    setState(() => _ocupados.add(p.id!));
    try {
      await fn();
      await _cargar();
    } catch (err) {
      if (mounted) _aviso(_mensaje(err, 'No se pudo guardar el cambio'));
    } finally {
      if (mounted) setState(() => _ocupados.remove(p.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final pin = coordenadasDe(widget.lugar);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.place_outlined, size: 18, color: _color),
            const SizedBox(width: 8),
            Expanded(child: Text('Puntos de interés', style: AppTypography.h3.copyWith(fontSize: 15))),
            DsButton(
              label: 'Agregar punto',
              icon: Icons.add_location_alt_outlined,
              variant: DsButtonVariant.secondary,
              accent: _color,
              size: DsButtonSize.sm,
              onPressed: pin == null || _puntos == null ? null : () => _editar(),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Cada punto funciona por capas: dentro del radio visible el visitante ve en la cámara un marcador '
          'flotante con el título y el resumen; dentro del radio cercano se abre la guía completa '
          '(información, imagen y audio).',
          style: AppTypography.bodySmall,
        ),
        const SizedBox(height: AppSpacing.md),
        if (pin == null)
          Text('Primero guarda las coordenadas del lugar (arriba).', style: TextStyle(color: AppColors.amber, fontSize: 13))
        else if (_error != null)
          DsErrorState(message: _error!, onRetry: _cargar)
        else if (_puntos == null)
          DsLoadingState(accent: _color)
        else ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.button),
            child: SizedBox(
              height: 300,
              child: MapaBase(
                centro: pin,
                zoom: 17,
                zoomConRueda: false,
                children: [..._capasPuntos(_puntos!.isEmpty ? [PuntoRaGeo(titulo: '', ubicacion: pin)] : _puntos!)],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (_puntos!.isEmpty)
            Text(
              'Sin puntos todavía: la app usa el pin del lugar como punto único '
              '(marcador a ${radioVisibleDefault.round()} m y guía completa a ${radioCercanoDefault.round()} m).',
              style: AppTypography.bodySmall,
            )
          else
            for (final (i, p) in _puntos!.indexed)
              _FilaPunto(
                numero: i + 1,
                punto: p,
                color: _color,
                ocupado: _ocupados.contains(p.id),
                onEditar: () => _editar(p),
                onBorrar: () => _borrar(p),
                onActivo: (v) => _alternarActivo(p, v),
              ),
        ],
      ],
    );
  }

  /// Círculo claro = radio visible; círculo fuerte = radio cercano.
  List<Widget> _capasPuntos(List<PuntoRaGeo> puntos) => [
        CircleLayer(circles: [
          for (final p in puntos) ...[
            CircleMarker(
              point: toLatLng(p.ubicacion),
              radius: p.radioVisible,
              useRadiusInMeter: true,
              color: _color.withValues(alpha: p.activo ? 0.10 : 0.04),
              borderColor: _color.withValues(alpha: 0.5),
              borderStrokeWidth: 1.5,
            ),
            CircleMarker(
              point: toLatLng(p.ubicacion),
              radius: p.radioCercano,
              useRadiusInMeter: true,
              color: _color.withValues(alpha: p.activo ? 0.35 : 0.1),
              borderColor: _color,
              borderStrokeWidth: 2,
            ),
          ],
        ]),
        MarkerLayer(markers: [
          for (final (i, p) in puntos.indexed)
            Marker(
              point: toLatLng(p.ubicacion),
              width: 26,
              height: 26,
              child: _NumeroPunto(numero: i + 1, color: p.activo ? _color : AppColors.slate500),
            ),
        ]),
      ];
}

class _NumeroPunto extends StatelessWidget {
  final int numero;
  final Color color;

  const _NumeroPunto({required this.numero, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
      child: Text('$numero', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
    );
  }
}

class _FilaPunto extends StatelessWidget {
  final int numero;
  final PuntoRaGeo punto;
  final Color color;
  final bool ocupado;
  final VoidCallback onEditar;
  final VoidCallback onBorrar;
  final ValueChanged<bool> onActivo;

  const _FilaPunto({
    required this.numero,
    required this.punto,
    required this.color,
    required this.ocupado,
    required this.onEditar,
    required this.onBorrar,
    required this.onActivo,
  });

  @override
  Widget build(BuildContext context) {
    final extras = [
      if (punto.imagenUrl.isNotEmpty) 'imagen',
      if (punto.audioUrl.isNotEmpty) 'audio',
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.panelNavySoft,
          borderRadius: BorderRadius.circular(AppRadius.button),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Row(
          children: [
            _NumeroPunto(numero: numero, color: punto.activo ? color : AppColors.slate500),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(punto.titulo, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
                  if (punto.resumen.isNotEmpty)
                    Text(punto.resumen, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.bodySmall),
                  const SizedBox(height: 2),
                  Text(
                    [
                      '${punto.ubicacion}',
                      'marcador ${formatoDistancia(punto.radioVisible)}',
                      'guía ${formatoDistancia(punto.radioCercano)}',
                      if (extras.isNotEmpty) extras.join(' + '),
                    ].join(' · '),
                    style: AppTypography.caption,
                  ),
                ],
              ),
            ),
            if (ocupado)
              const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            else ...[
              Tooltip(
                message: punto.activo ? 'Visible para los visitantes' : 'Oculto',
                child: Switch(value: punto.activo, onChanged: onActivo),
              ),
              IconButton(tooltip: 'Editar', onPressed: onEditar, icon: Icon(Icons.edit_outlined, size: 18, color: AppColors.slate300)),
              IconButton(tooltip: 'Borrar', onPressed: onBorrar, icon: Icon(Icons.delete_outline, size: 18, color: AppColors.errorRed)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Formulario de un punto: datos, coordenadas (pegadas o tocando el mapa) y
/// los dos radios. Devuelve el punto guardado.
class _DialogoPunto extends StatefulWidget {
  final NegocioSummary lugar;
  final PuntoRaGeo? punto;
  final int numero;
  final RaGeoService service;

  const _DialogoPunto({required this.lugar, this.punto, required this.numero, required this.service});

  @override
  State<_DialogoPunto> createState() => _DialogoPuntoState();
}

class _DialogoPuntoState extends State<_DialogoPunto> {
  final _form = GlobalKey<FormState>();
  late final _titulo = TextEditingController(text: widget.punto?.titulo ?? (widget.numero == 1 ? widget.lugar.nombre : ''));
  late final _resumen = TextEditingController(text: widget.punto?.resumen ?? '');
  late final _detalle = TextEditingController(text: widget.punto?.detalle ?? widget.lugar.descripcion ?? '');
  late final _imagen = TextEditingController(text: widget.punto?.imagenUrl ?? '');
  late final _audio = TextEditingController(text: widget.punto?.audioUrl ?? '');
  late Coordenadas? _ubicacion = widget.punto?.ubicacion ?? coordenadasDe(widget.lugar);
  late double _visible = widget.punto?.radioVisible ?? radioVisibleDefault;
  late double _cercano = widget.punto?.radioCercano ?? radioCercanoDefault;
  bool _guardando = false;
  String? _error;

  Color get _color => ExperienciaInfo.of(ExperienciaTipo.arGeo).color;

  @override
  void dispose() {
    for (final c in [_titulo, _resumen, _detalle, _imagen, _audio]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _validarUrl(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return null;
    final uri = Uri.tryParse(t);
    return uri != null && (uri.scheme == 'https' || uri.scheme == 'http') && uri.host.isNotEmpty
        ? null
        : 'Pega un enlace completo (https://…)';
  }

  Future<void> _guardar() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    if (_ubicacion == null) {
      setState(() => _error = 'Marca el punto en el mapa o pega sus coordenadas');
      return;
    }
    final token = SessionStorage.token;
    if (token == null) return;
    setState(() {
      _guardando = true;
      _error = null;
    });
    final punto = PuntoRaGeo(
      titulo: _titulo.text.trim(),
      resumen: _resumen.text.trim(),
      detalle: _detalle.text.trim(),
      imagenUrl: _imagen.text.trim(),
      audioUrl: _audio.text.trim(),
      ubicacion: _ubicacion!,
      radioVisible: _visible,
      radioCercano: _cercano,
      activo: widget.punto?.activo ?? true,
    );
    try {
      final guardado = widget.punto == null
          ? await widget.service.crear(token, widget.lugar.id, punto)
          : await widget.service.actualizar(token, widget.punto!.id!, punto.toJson());
      if (mounted) Navigator.of(context).pop(guardado);
    } catch (err) {
      if (mounted) setState(() => _error = _mensaje(err, 'No se pudo guardar el punto'));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Widget _slider({
    required String titulo,
    required String ayuda,
    required double valor,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(titulo, style: TextStyle(color: AppColors.slate300, fontSize: 14))),
            Text('${valor.round()} m', style: TextStyle(color: _color, fontWeight: FontWeight.w700)),
          ],
        ),
        Slider(
          value: valor.clamp(min, max),
          min: min,
          max: max,
          divisions: (max - min).round(),
          onChanged: _guardando ? null : onChanged,
        ),
        Text(ayuda, style: AppTypography.caption),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.panelNavySoft,
      insetPadding: const EdgeInsets.all(AppSpacing.lg),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(widget.punto == null ? 'Nuevo punto de interés' : 'Editar punto ${widget.numero}', style: AppTypography.h3),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  label: 'Título (se ve en el marcador flotante)',
                  icon: Icons.title,
                  controller: _titulo,
                  hintText: 'Ej. Entrada principal de FIME',
                  accentColor: _color,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Escribe un título' : null,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Resumen (una o dos líneas, se lee desde lejos)',
                  icon: Icons.short_text,
                  controller: _resumen,
                  hintText: 'Ej. Facultad de Ingeniería Electromecánica de la UdeC',
                  accentColor: _color,
                  validator: (v) => (v?.trim().length ?? 0) > 200 ? 'Máximo 200 caracteres' : null,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Guía completa (se abre al llegar al punto)',
                  icon: Icons.menu_book_outlined,
                  controller: _detalle,
                  maxLines: 5,
                  hintText: 'Historia, qué hay aquí, horarios, recomendaciones…',
                  accentColor: _color,
                  validator: (v) => (v?.trim().length ?? 0) > 4000 ? 'Máximo 4000 caracteres' : null,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Imagen (opcional)',
                  icon: Icons.image_outlined,
                  controller: _imagen,
                  hintText: 'https://…/foto.jpg',
                  keyboardType: TextInputType.url,
                  accentColor: _color,
                  validator: _validarUrl,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Guía de audio (opcional, MP3)',
                  icon: Icons.headphones_outlined,
                  controller: _audio,
                  hintText: 'https://…/guia.mp3',
                  keyboardType: TextInputType.url,
                  accentColor: _color,
                  validator: _validarUrl,
                ),
                const SizedBox(height: AppSpacing.lg),
                CampoCoordenadas(
                  lugar: 'el punto',
                  inicial: _ubicacion,
                  acento: _color,
                  habilitado: !_guardando,
                  marcarEnMapa: true,
                  onChanged: (c) => setState(() => _ubicacion = c),
                ),
                const SizedBox(height: AppSpacing.lg),
                _slider(
                  titulo: 'Radio visible (marcador flotante)',
                  ayuda: 'Desde esta distancia el visitante ve el marcador en la cámara.',
                  valor: _visible,
                  min: 20,
                  max: 500,
                  onChanged: (v) => setState(() {
                    _visible = v.roundToDouble();
                    if (_cercano >= _visible) _cercano = (_visible - 5).clamp(3, 100);
                  }),
                ),
                const SizedBox(height: AppSpacing.md),
                _slider(
                  titulo: 'Radio cercano (guía completa)',
                  ayuda: 'Al estar a esta distancia se abre la guía. Menos de 5 m suele ser menor que el error del GPS.',
                  valor: _cercano,
                  min: 3,
                  max: 100,
                  onChanged: (v) => setState(() => _cercano = v.roundToDouble().clamp(3, _visible - 1)),
                ),
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(_error!, style: TextStyle(color: AppColors.errorRed, fontSize: 13)),
                ],
                const SizedBox(height: AppSpacing.lg),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: AppSpacing.sm,
                  children: [
                    DsButton(label: 'Cancelar', variant: DsButtonVariant.ghost, onPressed: () => Navigator.of(context).pop()),
                    DsButton(
                      label: _guardando ? 'Guardando…' : 'Guardar punto',
                      icon: Icons.check,
                      variant: DsButtonVariant.primary,
                      accent: _color,
                      onPressed: _guardando ? null : _guardar,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
