import 'package:flutter/material.dart';

import '../../models/lugar.dart';
import '../../services/auth_service.dart';
import '../../services/session_storage.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin/ds_button.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/mapa/ubicacion_lugar.dart';
import '../../widgets/aviso.dart';

// Formularios en línea de "Mapa y RA": registrar/editar un lugar, su RA por
// ubicación (coordenadas) y sus marcadores de RA. Van dentro de
// [SeccionDesplegable], no en ventanas flotantes.

/// "Cerro del Vigía" → "cerro_del_vigia": formato de los identificadores de
/// marcadores y recorridos (minúsculas, números, _ o -).
String slugDe(String texto) {
  const acentos = {'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u', 'ñ': 'n'};
  final t = texto.toLowerCase().split('').map((c) => acentos[c] ?? c).join();
  final slug = t.replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(RegExp(r'^_+|_+$'), '');
  return slug.length > 45 ? slug.substring(0, 45) : slug;
}

String _mensaje(Object err, String porDefecto) => err is AuthError ? err.message : porDefecto;

Coordenadas? coordenadasDe(NegocioSummary n) => n.tieneUbicacion ? Coordenadas(n.latitud!, n.longitud!) : null;

// --- Registrar / editar un lugar ------------------------------------------------

/// Categorías que reconoce el mapa (ver CategoriaLugarDetector).
const categoriasLugar = ['Playa', 'Mirador', 'Restaurante', 'Hotel', 'Recreación', 'Cultura y educación', 'Otro'];

/// Formulario del lugar: nombre, categoría, dirección, coordenadas (con el
/// pin en el mapa) y resumen. Sin [lugar] registra uno nuevo. La información
/// detallada se edita en "RA por geolocalización" ([InformacionRaGeoSection]).
class LugarForm extends StatefulWidget {
  final NegocioSummary? lugar;
  final AuthService authService;
  final ValueChanged<NegocioSummary> onGuardado;
  final VoidCallback? onCancelar;

  const LugarForm({super.key, this.lugar, required this.authService, required this.onGuardado, this.onCancelar});

  @override
  State<LugarForm> createState() => _LugarFormState();
}

class _LugarFormState extends State<LugarForm> {
  final _form = GlobalKey<FormState>();
  late final _nombre = TextEditingController(text: widget.lugar?.nombre);
  late final _descripcion = TextEditingController(text: widget.lugar?.descripcion);
  late final _direccion = TextEditingController(text: widget.lugar?.direccion);
  late String? _categoria = widget.lugar?.categoria;
  late Coordenadas? _ubicacion = widget.lugar == null ? null : coordenadasDe(widget.lugar!);
  /// Cambia para limpiar el formulario después de registrar un lugar.
  int _version = 0;
  bool _guardando = false;
  String? _error;

  bool get _nuevo => widget.lugar == null;

  @override
  void dispose() {
    _nombre.dispose();
    _descripcion.dispose();
    _direccion.dispose();
    super.dispose();
  }

  String? _opcional(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _guardar() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final token = SessionStorage.token;
    if (token == null) return;
    setState(() {
      _guardando = true;
      _error = null;
    });
    final datos = {
      'nombre': _nombre.text.trim(),
      'categoria': _categoria,
      'descripcion': _opcional(_descripcion),
      'direccion': _opcional(_direccion),
      'latitud': _ubicacion?.lat,
      'longitud': _ubicacion?.lng,
    };
    try {
      final guardado = _nuevo
          ? await widget.authService.adminCrearLugar(token, datos)
          : await widget.authService.adminActualizarLugar(token, widget.lugar!.id, datos);
      if (!mounted) return;
      if (_nuevo) {
        // Listo para registrar otro.
        _nombre.clear();
        _descripcion.clear();
        _direccion.clear();
        setState(() {
          _categoria = null;
          _ubicacion = null;
          _version++;
        });
      }
      widget.onGuardado(guardado);
    } catch (err) {
      if (mounted) setState(() => _error = _mensaje(err, 'No se pudo guardar el lugar'));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categorias = [...categoriasLugar, if (_categoria != null && !categoriasLugar.contains(_categoria)) _categoria!];
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            label: 'Nombre del lugar',
            icon: Icons.place_outlined,
            controller: _nombre,
            hintText: 'Ej. Playa La Audiencia',
            accentColor: AppColors.adminViolet,
            validator: (v) {
              final t = v?.trim() ?? '';
              if (t.isEmpty) return 'Campo requerido';
              return t.length > 120 ? 'Máximo 120 caracteres' : null;
            },
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Categoría', style: TextStyle(color: AppColors.slate300, fontSize: 14)),
          const SizedBox(height: 8),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final c in categorias)
                ChoiceChip(
                  label: Text(c),
                  selected: _categoria == c,
                  onSelected: _guardando ? null : (_) => setState(() => _categoria = c),
                  selectedColor: AppColors.adminViolet.withValues(alpha: 0.2),
                  labelStyle: TextStyle(color: _categoria == c ? AppColors.adminViolet : AppColors.slate300, fontSize: 13),
                  backgroundColor: AppColors.surface,
                  side: BorderSide(color: AppColors.borderSubtle),
                  showCheckmark: false,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: 'Dirección',
            icon: Icons.signpost_outlined,
            controller: _direccion,
            hintText: 'Calle, número, colonia o referencia',
            accentColor: AppColors.adminViolet,
            validator: (v) => (v?.trim().length ?? 0) > 200 ? 'Máximo 200 caracteres' : null,
          ),
          const SizedBox(height: AppSpacing.md),
          CampoCoordenadas(
            key: ValueKey(_version),
            lugar: _nombre.text.trim().isEmpty ? 'el lugar' : _nombre.text.trim(),
            inicial: _ubicacion,
            habilitado: !_guardando,
            onChanged: (c) => _ubicacion = c,
            onDireccionSugerida: (direccion) {
              if (_direccion.text.trim().isEmpty) _direccion.text = direccion;
            },
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: 'Resumen',
            icon: Icons.short_text,
            controller: _descripcion,
            maxLines: 3,
            hintText: 'Ej. Playa de arena dorada y oleaje tranquilo, ideal para nadar.',
            accentColor: AppColors.adminViolet,
            validator: (v) => (v?.trim().length ?? 0) > 350 ? 'Máximo 350 caracteres' : null,
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(_error!, style: TextStyle(color: AppColors.errorRed, fontSize: 14)),
          ],
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              if (widget.onCancelar != null)
                DsButton(label: 'Cancelar', variant: DsButtonVariant.ghost, onPressed: _guardando ? null : widget.onCancelar),
              DsButton(
                label: _guardando ? 'Guardando…' : (_nuevo ? 'Registrar lugar' : 'Guardar cambios'),
                icon: Icons.check,
                variant: DsButtonVariant.primary,
                accent: AppColors.adminViolet,
                onPressed: _guardando ? null : _guardar,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// --- RA por ubicación ----------------------------------------------------------

/// Lo que necesita la RA por ubicación: el pin exacto del lugar (y su
/// dirección). Es el mismo pin del mapa y de "Cómo llegar".
class UbicacionLugarSection extends StatefulWidget {
  final NegocioSummary lugar;
  final AuthService authService;
  final ValueChanged<NegocioSummary> onGuardado;

  const UbicacionLugarSection({super.key, required this.lugar, required this.authService, required this.onGuardado});

  @override
  State<UbicacionLugarSection> createState() => _UbicacionLugarSectionState();
}

class _UbicacionLugarSectionState extends State<UbicacionLugarSection> {
  late final _direccion = TextEditingController(text: widget.lugar.direccion);
  late Coordenadas? _ubicacion = coordenadasDe(widget.lugar);
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _direccion.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final token = SessionStorage.token;
    if (token == null) return;
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final n = await widget.authService.adminActualizarLugar(token, widget.lugar.id, {
        'direccion': _direccion.text.trim().isEmpty ? null : _direccion.text.trim(),
        'latitud': _ubicacion?.lat,
        'longitud': _ubicacion?.lng,
      });
      if (!mounted) return;
      widget.onGuardado(n);
      ScaffoldMessenger.of(context).showSnackBar(aviso('Ubicación guardada'));
    } catch (err) {
      if (mounted) setState(() => _error = _mensaje(err, 'No se pudo guardar la ubicación'));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = ExperienciaInfo.of(ExperienciaTipo.arGeo).color;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CampoCoordenadas(
          lugar: widget.lugar.nombre,
          inicial: _ubicacion,
          acento: color,
          habilitado: !_guardando,
          onChanged: (c) => _ubicacion = c,
          onDireccionSugerida: (direccion) {
            if (_direccion.text.trim().isEmpty) _direccion.text = direccion;
          },
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          label: 'Dirección',
          icon: Icons.signpost_outlined,
          controller: _direccion,
          hintText: 'Calle, número, colonia o referencia',
          accentColor: color,
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(_error!, style: TextStyle(color: AppColors.errorRed, fontSize: 14)),
        ],
        const SizedBox(height: AppSpacing.md),
        Align(
          alignment: Alignment.centerRight,
          child: DsButton(
            label: _guardando ? 'Guardando…' : 'Guardar ubicación',
            icon: Icons.check,
            variant: DsButtonVariant.primary,
            accent: color,
            onPressed: _guardando ? null : _guardar,
          ),
        ),
      ],
    );
  }
}

// --- RA con marcador -------------------------------------------------------------

/// Marcadores (imágenes que reconoce la cámara) del lugar: verlos,

/// Lo que despliega la RA por geolocalización al llegar al lugar: la
/// información detallada (campo `detalle` del lugar). Desde lejos se lee el
/// resumen de "Datos del lugar".
class InformacionRaGeoSection extends StatefulWidget {
  final NegocioSummary lugar;
  final AuthService authService;
  final ValueChanged<NegocioSummary> onGuardado;

  const InformacionRaGeoSection({super.key, required this.lugar, required this.authService, required this.onGuardado});

  @override
  State<InformacionRaGeoSection> createState() => _InformacionRaGeoSectionState();
}

class _InformacionRaGeoSectionState extends State<InformacionRaGeoSection> {
  final _form = GlobalKey<FormState>();
  late final _detalle = TextEditingController(text: widget.lugar.detalle);
  bool _guardando = false;
  String? _error;

  Color get _color => ExperienciaInfo.of(ExperienciaTipo.arGeo).color;

  @override
  void dispose() {
    _detalle.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final token = SessionStorage.token;
    if (token == null) return;
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final texto = _detalle.text.trim();
      final g = await widget.authService
          .adminActualizarLugar(token, widget.lugar.id, {'detalle': texto.isEmpty ? null : texto});
      if (!mounted) return;
      widget.onGuardado(g);
      ScaffoldMessenger.of(context).showSnackBar(aviso('Información guardada'));
    } catch (err) {
      if (mounted) setState(() => _error = _mensaje(err, 'No se pudo guardar la información'));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final resumen = widget.lugar.descripcion?.trim() ?? '';
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Lo que ve el visitante en la cámara', style: AppTypography.h3.copyWith(fontSize: 15)),
          const SizedBox(height: 4),
          Text(
            'Desde lejos: el resumen del lugar${resumen.isEmpty ? ' (todavía no tiene; agrégalo en "Datos del lugar")' : ''}. '
            'Al llegar: la información detallada de aquí abajo.',
            style: AppTypography.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: 'Información detallada (se despliega al llegar)',
            icon: Icons.tips_and_updates_outlined,
            controller: _detalle,
            maxLines: 9,
            hintText: 'Datos curiosos, qué hacer, horarios, recomendaciones…',
            accentColor: _color,
            validator: (v) => (v?.trim().length ?? 0) > 5000 ? 'Máximo 5000 caracteres' : null,
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(_error!, style: TextStyle(color: AppColors.errorRed, fontSize: 14)),
          ],
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerRight,
            child: DsButton(
              label: _guardando ? 'Guardando…' : 'Guardar información',
              icon: Icons.check,
              variant: DsButtonVariant.primary,
              accent: _color,
              onPressed: _guardando ? null : _guardar,
            ),
          ),
        ],
      ),
    );
  }
}
