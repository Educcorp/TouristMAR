import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../models/lugar.dart';
import '../../services/ar_service.dart';
import '../../services/auth_service.dart';
import '../../services/session_storage.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin/ds_button.dart';
import '../../widgets/admin/ds_card.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/mapa/ubicacion_lugar.dart';

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
/// pin en el mapa) y descripción. Sin [lugar] registra uno nuevo.
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
                  labelStyle: TextStyle(color: _categoria == c ? AppColors.adminViolet : AppColors.slate300, fontSize: 12),
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
            label: 'Descripción',
            icon: Icons.notes,
            controller: _descripcion,
            maxLines: 3,
            hintText: 'Ej. Playa de arena dorada y oleaje tranquilo, ideal para nadar.',
            accentColor: AppColors.adminViolet,
            validator: (v) => (v?.trim().length ?? 0) > 350 ? 'Máximo 350 caracteres' : null,
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(_error!, style: TextStyle(color: AppColors.errorRed, fontSize: 13)),
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ubicación guardada')));
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
          Text(_error!, style: TextStyle(color: AppColors.errorRed, fontSize: 13)),
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
/// activarlos/desactivarlos, borrarlos y agregar nuevos.
class MarcadoresLugarSection extends StatefulWidget {
  final NegocioSummary lugar;
  final ArService arService;
  final VoidCallback? onCambio;

  MarcadoresLugarSection({super.key, required this.lugar, ArService? arService, this.onCambio})
      : arService = arService ?? ArService();

  @override
  State<MarcadoresLugarSection> createState() => _MarcadoresLugarSectionState();
}

class _MarcadoresLugarSectionState extends State<MarcadoresLugarSection> {
  final _form = GlobalKey<FormState>();
  late final _nombre = TextEditingController(text: '${slugDe(widget.lugar.nombre)}_01');
  late final _titulo = TextEditingController(text: widget.lugar.nombre);
  final _texto = TextEditingController();
  final _ancho = TextEditingController();
  PlatformFile? _imagen;

  List<ArMarcador>? _marcadores;
  bool _ocupado = false;
  bool _mostrarForm = false;
  String? _error;

  ExperienciaInfo get _info => ExperienciaInfo.of(ExperienciaTipo.arMarcador);

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _nombre.dispose();
    _titulo.dispose();
    _texto.dispose();
    _ancho.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    final token = SessionStorage.token;
    if (token == null) return;
    try {
      final todos = await widget.arService.listMarcadores(token);
      if (mounted) setState(() => _marcadores = todos.where((m) => m.negocioId == widget.lugar.id).toList());
    } catch (err) {
      if (mounted) setState(() => _error = _mensaje(err, 'No se pudieron cargar los marcadores'));
    }
  }

  Future<void> _elegirImagen() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['jpg', 'jpeg', 'png'], withData: true);
    final f = r?.files.single;
    if (f != null && f.bytes != null) setState(() => _imagen = f);
  }

  Future<void> _ejecutar(Future<void> Function(String token) accion, String error) async {
    final token = SessionStorage.token;
    if (token == null) return;
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      await accion(token);
      widget.onCambio?.call();
    } catch (err) {
      if (mounted) setState(() => _error = _mensaje(err, error));
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _crear() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    if (_imagen == null) {
      setState(() => _error = 'Elige la imagen que reconocerá la cámara');
      return;
    }
    await _ejecutar((token) async {
      final m = await widget.arService.createMarcador(
        token,
        imagen: _imagen!.bytes!,
        filename: _imagen!.name,
        nombre: _nombre.text.trim().toLowerCase(),
        titulo: _titulo.text.trim(),
        texto: _texto.text.trim(),
        anchoMetros: double.tryParse(_ancho.text.trim().replaceAll(',', '.')),
        negocioId: widget.lugar.id,
      );
      if (!mounted) return;
      setState(() {
        _marcadores = [...?_marcadores, m];
        _imagen = null;
        _texto.clear();
        _ancho.clear();
        _nombre.text = '${slugDe(widget.lugar.nombre)}_${(_marcadores!.length + 1).toString().padLeft(2, '0')}';
        _mostrarForm = false;
      });
    }, 'No se pudo crear el marcador');
  }

  Future<void> _activar(ArMarcador m, bool activo) => _ejecutar((token) async {
        final nuevo = await widget.arService.updateMarcador(token, m.id, {'activo': activo});
        if (mounted) setState(() => _marcadores = [for (final x in _marcadores!) x.id == m.id ? nuevo : x]);
      }, 'No se pudo actualizar el marcador');

  Future<void> _eliminar(ArMarcador m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.panelNavySoft,
        title: Text('Eliminar marcador', style: TextStyle(color: AppColors.textPrimary)),
        content: Text('"${m.titulo}" dejará de reconocerse en la app.', style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text('Cancelar', style: TextStyle(color: AppColors.slate400))),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text('Eliminar', style: TextStyle(color: AppColors.errorRed))),
        ],
      ),
    );
    if (ok != true) return;
    await _ejecutar((token) async {
      await widget.arService.deleteMarcador(token, m.id);
      if (mounted) setState(() => _marcadores = _marcadores!.where((x) => x.id != m.id).toList());
    }, 'No se pudo eliminar el marcador');
  }

  @override
  Widget build(BuildContext context) {
    final color = _info.color;
    final lista = _marcadores;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                lista == null
                    ? ''
                    : lista.isEmpty
                        ? 'Sin marcadores.'
                        : '${lista.length} ${lista.length == 1 ? 'marcador' : 'marcadores'}',
                style: AppTypography.bodySmall,
              ),
            ),
            if (!_mostrarForm)
              DsButton(
                label: 'Nuevo marcador',
                icon: Icons.add,
                size: DsButtonSize.sm,
                variant: DsButtonVariant.primary,
                accent: color,
                onPressed: () => setState(() => _mostrarForm = true),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (lista == null && _error == null)
          const Center(child: Padding(padding: EdgeInsets.all(AppSpacing.md), child: CircularProgressIndicator()))
        else
          for (final m in lista ?? const <ArMarcador>[])
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: DsCard(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(m.imagenUrl, width: 56, height: 56, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(Icons.broken_image_outlined, color: AppColors.slate500)),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(m.titulo,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                          Text('${m.nombre} · ${m.escaneos} escaneos', style: AppTypography.caption),
                        ],
                      ),
                    ),
                    Tooltip(
                      message: m.activo ? 'Visible en la app' : 'Oculto',
                      child: Switch(value: m.activo, onChanged: _ocupado ? null : (v) => _activar(m, v)),
                    ),
                    IconButton(
                      tooltip: 'Eliminar',
                      onPressed: _ocupado ? null : () => _eliminar(m),
                      icon: Icon(Icons.delete_outline, size: 18, color: AppColors.errorRed),
                    ),
                  ],
                ),
              ),
            ),
        if (_mostrarForm)
          DsCard(
            background: color.withValues(alpha: 0.05),
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Nuevo marcador', style: AppTypography.h3),
                  const SizedBox(height: AppSpacing.md),
                  InkWell(
                    onTap: _ocupado ? null : _elegirImagen,
                    borderRadius: BorderRadius.circular(AppRadius.button),
                    child: Container(
                      height: 140,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(AppRadius.button),
                        border: Border.all(color: color.withValues(alpha: 0.4)),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _imagen == null
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_photo_alternate_outlined, color: color),
                                const SizedBox(height: 4),
                                Text('Elegir imagen', style: AppTypography.caption),
                              ],
                            )
                          : Image.memory(_imagen!.bytes!, fit: BoxFit.contain),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    label: 'Identificador',
                    icon: Icons.label_outline,
                    controller: _nombre,
                    hintText: 'Ej. audiencia_letrero_01',
                    accentColor: color,
                    validator: (v) {
                      final t = v?.trim().toLowerCase() ?? '';
                      if (t.isEmpty) return 'Campo requerido';
                      if (t.length > 60) return 'Máximo 60 caracteres';
                      return RegExp(r'^[a-z0-9_-]+$').hasMatch(t) ? null : 'Solo minúsculas, números, _ o -';
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    label: 'Título',
                    icon: Icons.title,
                    controller: _titulo,
                    accentColor: color,
                    validator: (v) => (v?.trim().isEmpty ?? true) ? 'Campo requerido' : ((v!.trim().length > 80) ? 'Máximo 80 caracteres' : null),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    label: 'Información que aparece encima',
                    icon: Icons.notes,
                    controller: _texto,
                    maxLines: 3,
                    hintText: 'Ej. Playa La Audiencia: bahía de aguas tranquilas rodeada de palapas.',
                    accentColor: color,
                    validator: (v) => (v?.trim().isEmpty ?? true) ? 'Campo requerido' : ((v!.trim().length > 500) ? 'Máximo 500 caracteres' : null),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    label: 'Ancho real impreso, en metros (opcional)',
                    icon: Icons.straighten,
                    controller: _ancho,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    hintText: 'Ej. 0.30',
                    accentColor: color,
                    validator: (v) {
                      final t = v?.trim().replaceAll(',', '.') ?? '';
                      if (t.isEmpty) return null;
                      final n = double.tryParse(t);
                      return n == null || n <= 0 || n > 20 ? 'Entre 0 y 20 metros' : null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: AppSpacing.sm,
                    children: [
                      DsButton(
                        label: 'Cancelar',
                        variant: DsButtonVariant.ghost,
                        onPressed: _ocupado ? null : () => setState(() => _mostrarForm = false),
                      ),
                      DsButton(
                        label: _ocupado ? 'Guardando…' : 'Agregar marcador',
                        icon: Icons.add,
                        variant: DsButtonVariant.primary,
                        accent: color,
                        onPressed: _ocupado ? null : _crear,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(_error!, style: TextStyle(color: AppColors.errorRed, fontSize: 13)),
        ],
      ],
    );
  }
}
