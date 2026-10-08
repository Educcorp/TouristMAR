import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../models/lugar.dart';
import '../../services/auth_service.dart';
import '../../services/recorridos_service.dart';
import '../../services/session_storage.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin/ds_badge.dart';
import '../../widgets/admin/ds_button.dart';
import '../../widgets/admin/ds_card.dart';
import '../../widgets/admin/ds_states.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/mapa/ubicacion_lugar.dart';
import '../../widgets/recorrido360/visor_360.dart';

/// Mismo límite que multer en recorridos.routes.ts.
const _maxMb = 30;

String _formatMb(int bytes) => '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';

/// Normaliza un ángulo a -180…180 (el rango que acepta el backend).
double _normalizarYaw(double grados) {
  final y = ((grados + 180) % 360 + 360) % 360 - 180;
  return double.parse(y.toStringAsFixed(1));
}

/// Ordena "escena_2.jpg" antes que "escena_10.jpg" (las apps de captura
/// numeran así las fotos).
int _compararNatural(String a, String b) {
  final partes = RegExp(r'\d+|\D+');
  final pa = partes.allMatches(a.toLowerCase()).map((m) => m[0]!).toList();
  final pb = partes.allMatches(b.toLowerCase()).map((m) => m[0]!).toList();
  for (var i = 0; i < pa.length && i < pb.length; i++) {
    final na = int.tryParse(pa[i]);
    final nb = int.tryParse(pb[i]);
    final c = na != null && nb != null ? na.compareTo(nb) : pa[i].compareTo(pb[i]);
    if (c != 0) return c;
  }
  return pa.length.compareTo(pb.length);
}

/// Sección "Recorrido 360°" de un lugar (dentro de "Mapa y RA" →
/// `/admin/mapa/lugar/<id>`): los recorridos de ese lugar, el formulario para
/// registrar uno nuevo y, al abrir uno, su editor de escenarios (visor 360°,
/// fotos y flechas). Lo que se guarda aquí lo ve el turista al tocar "Ver en
/// 360°" en el mapa o en la ficha del lugar, con el visor de Flutter (web y
/// teléfono, `GET /api/recorridos`).
class RecorridosLugarSection extends StatefulWidget {
  final NegocioSummary lugar;
  final RecorridosService recorridosService;

  /// Avisa que cambió algo (para refrescar el resumen del lugar).
  final VoidCallback? onCambio;

  RecorridosLugarSection({super.key, required this.lugar, RecorridosService? recorridosService, this.onCambio})
      : recorridosService = recorridosService ?? RecorridosService();

  @override
  State<RecorridosLugarSection> createState() => _RecorridosLugarSectionState();
}

class _RecorridosLugarSectionState extends State<RecorridosLugarSection> {
  List<Recorrido360> _recorridos = [];
  bool _loading = true;
  String? _error;
  final Set<String> _busy = {};

  // Formulario: abierto para alta (`_editing == null`) o edición.
  bool _showForm = false;
  Recorrido360? _editing;

  /// Recorrido cuyos escenarios se están editando.
  String? _abiertoId;

  Recorrido360? get _abierto {
    for (final r in _recorridos) {
      if (r.id == _abiertoId) return r;
    }
    return null;
  }

  Coordenadas? get _pinLugar =>
      widget.lugar.tieneUbicacion ? Coordenadas(widget.lugar.latitud!, widget.lugar.longitud!) : null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = SessionStorage.token;
    if (token == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final todos = await widget.recorridosService.listRecorridos(token);
      if (!mounted) return;
      setState(() => _recorridos = todos.where((r) => r.negocioId == widget.lugar.id).toList());
    } catch (err) {
      if (!mounted) return;
      setState(() => _error = err is AuthError ? err.message : 'No se pudo conectar con el servidor');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openForm([Recorrido360? recorrido]) => setState(() {
        _editing = recorrido;
        _showForm = true;
      });

  void _closeForm() => setState(() {
        _showForm = false;
        _editing = null;
      });

  void _replace(Recorrido360 updated) {
    setState(() {
      final i = _recorridos.indexWhere((r) => r.id == updated.id);
      if (i >= 0) {
        _recorridos[i] = updated;
      } else {
        _recorridos = [updated, ..._recorridos];
      }
    });
    widget.onCambio?.call();
  }

  void _onSaved(Recorrido360 saved) {
    final esNuevo = !_recorridos.any((r) => r.id == saved.id);
    _replace(saved);
    setState(() {
      _showForm = false;
      _editing = null;
      // Recién creado: directo a subir sus escenarios.
      if (esNuevo) _abiertoId = saved.id;
    });
  }

  Future<void> _toggleActivo(Recorrido360 recorrido, bool activo) async {
    final token = SessionStorage.token;
    if (token == null) return;
    setState(() => _busy.add(recorrido.id));
    try {
      _replace(await widget.recorridosService.updateRecorrido(token, recorrido.id, {'activo': activo}));
    } catch (err) {
      _snack(err is AuthError ? err.message : 'No se pudo actualizar el recorrido');
    } finally {
      if (mounted) setState(() => _busy.remove(recorrido.id));
    }
  }

  Future<void> _delete(Recorrido360 recorrido) async {
    final confirmed = await _confirmar(
      context,
      titulo: 'Eliminar recorrido',
      mensaje: '"${recorrido.titulo}" y sus ${recorrido.escenas.length} escenarios dejarán de estar en la app. '
          'Si solo quieres ocultarlo un tiempo, mejor desactívalo.',
    );
    if (!confirmed) return;

    final token = SessionStorage.token;
    if (token == null) return;
    setState(() => _busy.add(recorrido.id));
    try {
      await widget.recorridosService.deleteRecorrido(token, recorrido.id);
      if (!mounted) return;
      setState(() {
        _recorridos.removeWhere((r) => r.id == recorrido.id);
        if (_editing?.id == recorrido.id) _closeForm();
        if (_abiertoId == recorrido.id) _abiertoId = null;
      });
      widget.onCambio?.call();
    } catch (err) {
      _snack(err is AuthError ? err.message : 'No se pudo eliminar el recorrido');
    } finally {
      if (mounted) setState(() => _busy.remove(recorrido.id));
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final abierto = _abierto;
    if (abierto != null && !_showForm) {
      return _EscenariosEditor(
        key: ValueKey(abierto.id),
        recorrido: abierto,
        lugarNombre: widget.lugar.nombre,
        service: widget.recorridosService,
        onChanged: _replace,
        onBack: () => setState(() => _abiertoId = null),
        onEditarDatos: () => _openForm(abierto),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _loading
                    ? ''
                    : _recorridos.isEmpty
                        ? 'Sin recorridos.'
                        : '${_recorridos.length} ${_recorridos.length == 1 ? 'recorrido' : 'recorridos'} · '
                            '${_recorridos.where((r) => r.publicado).length} visibles en la app',
                style: AppTypography.bodySmall,
              ),
            ),
            if (!_showForm)
              DsButton(
                label: 'Nuevo recorrido',
                icon: Icons.add,
                size: DsButtonSize.sm,
                variant: DsButtonVariant.primary,
                accent: AppColors.adminViolet,
                onPressed: _loading ? null : () => _openForm(),
              ),
          ],
        ),
        if (_showForm) ...[
          const SizedBox(height: AppSpacing.md),
          _RecorridoForm(
            key: ValueKey(_editing?.id ?? 'nuevo'),
            recorrido: _editing,
            lugar: widget.lugar,
            pinLugar: _pinLugar,
            service: widget.recorridosService,
            onCancel: _closeForm,
            onSaved: _onSaved,
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        if (_loading)
          DsLoadingState(accent: AppColors.adminViolet)
        else if (_error != null)
          DsErrorState(message: _error!, onRetry: _load)
        else
          for (final r in _recorridos)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _RecorridoRow(
                recorrido: r,
                sinUbicacion: !r.tieneUbicacion,
                busy: _busy.contains(r.id),
                onToggle: (v) => _toggleActivo(r, v),
                onAbrir: () => setState(() => _abiertoId = r.id),
                onEdit: () => _openForm(r),
                onDelete: () => _delete(r),
              ),
            ),
      ],
    );
  }
}

Future<bool> _confirmar(
  BuildContext context, {
  required String titulo,
  required String mensaje,
  String accion = 'Eliminar',
  bool peligro = true,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.panelNavySoft,
      title: Text(titulo, style: TextStyle(color: AppColors.textPrimary)),
      content: Text(mensaje, style: TextStyle(color: AppColors.textSecondary)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text('Cancelar', style: TextStyle(color: AppColors.slate400)),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(accion, style: TextStyle(color: peligro ? AppColors.errorRed : AppColors.adminViolet)),
        ),
      ],
    ),
  );
  return confirmed == true;
}

class _RecorridoForm extends StatefulWidget {
  final Recorrido360? recorrido;

  /// El lugar al que pertenece el recorrido (no se elige: es el de la página).
  final NegocioSummary lugar;
  final Coordenadas? pinLugar;
  final RecorridosService service;
  final VoidCallback onCancel;
  final ValueChanged<Recorrido360> onSaved;

  const _RecorridoForm({
    super.key,
    required this.recorrido,
    required this.lugar,
    required this.pinLugar,
    required this.service,
    required this.onCancel,
    required this.onSaved,
  });

  @override
  State<_RecorridoForm> createState() => _RecorridoFormState();
}

class _RecorridoFormState extends State<_RecorridoForm> {
  final _formKey = GlobalKey<FormState>();
  late final _nombre = TextEditingController(text: widget.recorrido?.nombre);
  late final _titulo = TextEditingController(text: widget.recorrido?.titulo);
  late final _texto = TextEditingController(text: widget.recorrido?.texto);
  /// Pin propio del recorrido. Si todavía no tiene, toma el del lugar (se
  /// puede cambiar: p. ej. la entrada del recorrido no es la del negocio).
  late Coordenadas? _ubicacion = widget.recorrido?.tieneUbicacion ?? false
      ? Coordenadas(widget.recorrido!.latitud!, widget.recorrido!.longitud!)
      : widget.pinLugar;

  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.recorrido != null;

  @override
  void dispose() {
    _nombre.dispose();
    _titulo.dispose();
    _texto.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final token = SessionStorage.token;
    if (token == null) return;

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final nombre = _nombre.text.trim().toLowerCase();
      final saved = _isEdit
          ? await widget.service.updateRecorrido(token, widget.recorrido!.id, {
              'nombre': nombre,
              'titulo': _titulo.text.trim(),
              'texto': _texto.text.trim(),
              'latitud': _ubicacion?.lat,
              'longitud': _ubicacion?.lng,
            })
          : await widget.service.createRecorrido(
              token,
              nombre: nombre,
              titulo: _titulo.text.trim(),
              texto: _texto.text.trim(),
              negocioId: widget.lugar.id,
              latitud: _ubicacion?.lat,
              longitud: _ubicacion?.lng,
            );
      if (!mounted) return;
      widget.onSaved(saved);
    } catch (err) {
      if (!mounted) return;
      setState(() => _error = err is AuthError ? err.message : 'No se pudo guardar el recorrido');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DsCard(
      background: AppColors.adminViolet.withValues(alpha: 0.05),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isEdit ? 'EDITAR RECORRIDO' : 'NUEVO RECORRIDO 360°',
              style: AppTypography.h3,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Identificador del recorrido',
              icon: Icons.label_outline,
              controller: _nombre,
              hintText: 'Ej. playa_audiencia_360',
              accentColor: AppColors.adminViolet,
              validator: _validarNombre,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Título que verá el turista',
              icon: Icons.title,
              controller: _titulo,
              hintText: 'Ej. Playa La Audiencia',
              accentColor: AppColors.adminViolet,
              validator: (v) => _required(v, 80),
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Información',
              icon: Icons.notes,
              controller: _texto,
              maxLines: 4,
              hintText: 'Ej. Recorre la playa desde el malecón hasta las palapas.',
              accentColor: AppColors.adminViolet,
              validator: (v) => _required(v, 500),
            ),
            const SizedBox(height: AppSpacing.md),
            CampoCoordenadas(
              lugar: _titulo.text.trim().isEmpty ? 'el recorrido' : _titulo.text.trim(),
              inicial: _ubicacion,
              habilitado: !_saving,
              onChanged: (c) => _ubicacion = c,
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(_error!, style: TextStyle(color: AppColors.errorRed, fontSize: 13)),
            ],
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                DsButton(label: 'Cancelar', variant: DsButtonVariant.ghost, onPressed: _saving ? null : widget.onCancel),
                DsButton(
                  label: _saving ? 'Guardando...' : (_isEdit ? 'Guardar cambios' : 'Crear y subir escenarios'),
                  variant: DsButtonVariant.primary,
                  accent: AppColors.adminViolet,
                  onPressed: _saving ? null : _save,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Mismo formato que valida el backend (nombreSchema en recorridos.controller.ts).
  static final _nombreValido = RegExp(r'^[a-z0-9_-]+$');

  String? _validarNombre(String? v) {
    final text = v?.trim().toLowerCase() ?? '';
    if (text.isEmpty) return 'Campo requerido';
    if (text.length > 60) return 'Máximo 60 caracteres';
    if (!_nombreValido.hasMatch(text)) return 'Solo minúsculas, números, _ o - (ej. cerro_vigia_360)';
    return null;
  }

  String? _required(String? v, int max) {
    final text = v?.trim() ?? '';
    if (text.isEmpty) return 'Campo requerido';
    if (text.length > max) return 'Máximo $max caracteres';
    return null;
  }
}

class _RecorridoRow extends StatelessWidget {
  final Recorrido360 recorrido;
  final bool sinUbicacion;
  final bool busy;
  final ValueChanged<bool> onToggle;
  final VoidCallback onAbrir;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _RecorridoRow({
    required this.recorrido,
    required this.sinUbicacion,
    required this.busy,
    required this.onToggle,
    required this.onAbrir,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final r = recorrido;
    final portada = r.escenas.isEmpty ? null : r.escenas.first.miniaturaUrl;
    final sinFlechas = r.escenas.length > 1 ? r.escenas.where((e) => e.enlaces.isEmpty).length : 0;
    return Opacity(
      opacity: r.activo ? 1 : 0.6,
      child: DsCard(
        onTap: onAbrir,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.button),
              child: Container(
                width: 128,
                height: 64,
                color: AppColors.panelNavySoft,
                child: portada == null
                    ? Icon(Icons.threesixty, color: AppColors.slate500)
                    : Image.network(
                        portada,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(Icons.broken_image_outlined, color: AppColors.slate500),
                      ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.titulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  Text(r.nombre, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.bodySmall),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      DsBadge(
                        text: r.negocioNombre ?? 'General',
                        tone: r.negocioNombre != null ? BadgeTone.info : BadgeTone.neutral,
                        icon: r.negocioNombre != null ? Icons.apartment_outlined : Icons.public,
                      ),
                      DsBadge(
                        text: '${r.escenas.length} ${r.escenas.length == 1 ? 'escenario' : 'escenarios'}',
                        tone: r.escenas.isEmpty ? BadgeTone.warning : BadgeTone.success,
                        icon: Icons.photo_library_outlined,
                      ),
                      if (r.escenas.isNotEmpty)
                        DsBadge(text: _formatMb(r.pesoTotalBytes), tone: BadgeTone.neutral, icon: Icons.download_outlined),
                      if (sinFlechas > 0)
                        DsBadge(text: '$sinFlechas sin flechas', tone: BadgeTone.warning, icon: Icons.alt_route),
                      if (sinUbicacion) const DsBadge(text: 'Sin coordenadas', tone: BadgeTone.warning, icon: Icons.location_off_outlined),
                      if (!r.activo) const DsBadge(text: 'Oculto', tone: BadgeTone.warning),
                      if (r.activo && r.escenas.isEmpty)
                        const DsBadge(text: 'Sin escenarios', tone: BadgeTone.warning),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            if (busy)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.adminViolet),
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Tooltip(
                    message: r.activo ? 'Visible en la app' : 'Oculto en la app',
                    child: Switch(value: r.activo, onChanged: onToggle),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Escenarios y flechas',
                        onPressed: onAbrir,
                        icon: Icon(Icons.threesixty, size: 18, color: AppColors.adminViolet),
                      ),
                      IconButton(
                        tooltip: 'Editar datos',
                        onPressed: onEdit,
                        icon: Icon(Icons.edit_outlined, size: 18, color: AppColors.slate300),
                      ),
                      IconButton(
                        tooltip: 'Eliminar',
                        onPressed: onDelete,
                        icon: Icon(Icons.delete_outline, size: 18, color: AppColors.errorRed),
                      ),
                    ],
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Vista de detalle de un recorrido: el visor 360° (igual al que verá el
/// turista) para revisar cada escenario y colocar sus flechas, y la
/// cuadrícula de escenarios para subir, ordenar y elegir cuál editar.
class _EscenariosEditor extends StatefulWidget {
  final Recorrido360 recorrido;
  final String? lugarNombre;
  final RecorridosService service;
  final ValueChanged<Recorrido360> onChanged;
  final VoidCallback onBack;
  final VoidCallback onEditarDatos;

  const _EscenariosEditor({
    super.key,
    required this.recorrido,
    required this.lugarNombre,
    required this.service,
    required this.onChanged,
    required this.onBack,
    required this.onEditarDatos,
  });

  @override
  State<_EscenariosEditor> createState() => _EscenariosEditorState();
}

class _EscenariosEditorState extends State<_EscenariosEditor> {
  final _visor = Visor360Controller();
  final _tituloEscena = TextEditingController();
  final _descripcionEscena = TextEditingController();

  String? _selId;
  /// Modo "Colocar flechas": tocar la foto agrega una flecha y tocar una
  /// flecha la edita. Si no, el visor se comporta como lo verá el turista.
  bool _colocando = false;
  bool _ocupado = false;

  // Subida de varios escenarios a la vez.
  int _subidaTotal = 0;
  int _subidaHechas = 0;
  String? _subidaArchivo;
  final List<String> _erroresSubida = [];

  Recorrido360 get _r => widget.recorrido;

  Escena360? get _sel {
    for (final e in _r.escenas) {
      if (e.id == _selId) return e;
    }
    return _r.escenas.isEmpty ? null : _r.escenas.first;
  }

  bool get _subiendo => _subidaTotal > 0 && _subidaHechas < _subidaTotal;

  @override
  void initState() {
    super.initState();
    _cargarCampos();
  }

  @override
  void dispose() {
    _tituloEscena.dispose();
    _descripcionEscena.dispose();
    super.dispose();
  }

  void _cargarCampos() {
    final e = _sel;
    _tituloEscena.text = e?.titulo ?? '';
    _descripcionEscena.text = e?.descripcion ?? '';
  }

  void _seleccionar(String id) {
    if (id == _sel?.id) return;
    setState(() => _selId = id);
    _cargarCampos();
  }

  String? get _token => SessionStorage.token;

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Reemplaza (o agrega) un escenario en el recorrido del padre.
  void _conEscena(Escena360 escena) {
    final escenas = [
      for (final e in _r.escenas)
        if (e.posicion != escena.posicion) e,
      escena,
    ]..sort((a, b) => a.posicion.compareTo(b.posicion));
    widget.onChanged(_r.copyWith(escenas: escenas));
  }

  Future<void> _recargar() async {
    final token = _token;
    if (token == null) return;
    final lista = await widget.service.listRecorridos(token);
    for (final r in lista) {
      if (r.id == _r.id) widget.onChanged(r);
    }
  }

  Future<void> _accion(Future<void> Function(String token) fn, String error) async {
    final token = _token;
    if (token == null) return;
    setState(() => _ocupado = true);
    try {
      await fn(token);
    } catch (err) {
      _snack(err is AuthError ? err.message : error);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  // --- Subida -------------------------------------------------------------

  Future<void> _subirVarios() async {
    final libres = [
      for (var p = 1; p <= maxEscenarios; p++)
        if (_r.foto(p) == null) p,
    ];
    if (libres.isEmpty) {
      _snack('El recorrido ya tiene los $maxEscenarios escenarios. Quita alguno para subir otro.');
      return;
    }
    // Como stream (no `withData`): el navegador no carga todas las fotos en
    // memoria a la vez, las va leyendo mientras las sube.
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png'],
      allowMultiple: true,
      withReadStream: true,
    );
    if (result == null || result.files.isEmpty) return;
    final archivos = [...result.files]..sort((a, b) => _compararNatural(a.name, b.name));
    if (archivos.length > libres.length) {
      _snack('Elegiste ${archivos.length} fotos pero solo quedan ${libres.length} lugares (máx. $maxEscenarios).');
      return;
    }
    final token = _token;
    if (token == null) return;

    setState(() {
      _subidaTotal = archivos.length;
      _subidaHechas = 0;
      _erroresSubida.clear();
    });
    String? primeraNueva;
    for (var i = 0; i < archivos.length; i++) {
      final file = archivos[i];
      final posicion = libres[i];
      if (!mounted) return;
      setState(() => _subidaArchivo = file.name);
      try {
        if (file.size > _maxMb * 1024 * 1024) throw const AuthError('pesa más de $_maxMb MB');
        if (file.readStream == null) throw const AuthError('no se pudo leer el archivo');
        final escena = await widget.service.setEscena(
          token,
          _r.id,
          posicion,
          bytes: file.readStream!,
          length: file.size,
          filename: file.name,
        );
        if (!mounted) return;
        _conEscena(escena);
        primeraNueva ??= escena.id;
      } catch (err) {
        _erroresSubida.add('${file.name}: ${err is AuthError ? err.message : 'no se pudo subir'}');
      }
      if (mounted) setState(() => _subidaHechas = i + 1);
    }
    if (!mounted) return;
    setState(() => _subidaArchivo = null);
    if (_selId == null && primeraNueva != null) _seleccionar(primeraNueva);
    final ok = archivos.length - _erroresSubida.length;
    _snack(_erroresSubida.isEmpty
        ? '$ok ${ok == 1 ? 'escenario subido' : 'escenarios subidos'}. Ahora conéctalos con flechas.'
        : '$ok de ${archivos.length} subidos. Revisa los que fallaron.');
  }

  Future<void> _reemplazarFoto(Escena360 escena) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png'],
      withReadStream: true,
    );
    final file = result?.files.single;
    if (file == null) return;
    if (file.size > _maxMb * 1024 * 1024 || file.readStream == null) {
      _snack(file.readStream == null ? 'No se pudo leer el archivo' : 'La foto pesa más de $_maxMb MB');
      return;
    }
    await _accion((token) async {
      _conEscena(await widget.service.setEscena(
        token,
        _r.id,
        escena.posicion,
        bytes: file.readStream!,
        length: file.size,
        filename: file.name,
      ));
    }, 'No se pudo subir la foto');
  }

  Future<void> _quitar(Escena360 escena) async {
    final entradas = _r.escenas.where((e) => e.enlaces.any((l) => l.destino == escena.posicion)).length;
    final confirmed = await _confirmar(
      context,
      titulo: 'Quitar "${escena.nombre}"',
      mensaje: 'Se borra la foto y sus flechas'
          '${entradas > 0 ? ', y también las $entradas flechas de otros escenarios que llevan a él' : ''}.',
    );
    if (!confirmed) return;
    await _accion((token) async {
      await widget.service.deleteEscena(token, _r.id, escena.posicion);
      if (_selId == escena.id) _selId = null;
      await _recargar();
      _cargarCampos();
    }, 'No se pudo quitar el escenario');
  }

  // --- Datos del escenario ------------------------------------------------

  Future<void> _guardarDatos(Escena360 escena) async {
    await _accion((token) async {
      _conEscena(await widget.service.updateEscena(token, _r.id, escena.posicion, {
        'titulo': _tituloEscena.text.trim(),
        'descripcion': _descripcionEscena.text.trim(),
      }));
      _snack('Escenario guardado');
    }, 'No se pudo guardar el escenario');
  }

  Future<void> _fijarVistaInicial(Escena360 escena) async {
    final yaw = _normalizarYaw(_visor.yaw);
    await _accion((token) async {
      _conEscena(await widget.service.updateEscena(token, _r.id, escena.posicion, {'yawInicial': yaw}));
      _snack('El turista entrará a "${escena.nombre}" mirando hacia aquí (${yaw.round()}°).');
    }, 'No se pudo guardar la vista inicial');
  }

  // --- Flechas ------------------------------------------------------------

  Future<void> _guardarFlechas(Escena360 escena, List<Enlace360> enlaces) async {
    await _accion((token) async {
      _conEscena(await widget.service.setEnlaces(token, _r.id, escena.posicion, enlaces));
    }, 'No se pudieron guardar las flechas');
  }

  Future<void> _agregarFlecha(double yaw, double pitch) async {
    final escena = _sel;
    if (escena == null || _ocupado) return;
    final ocupados = escena.enlaces.map((l) => l.destino).toSet();
    final opciones = [
      for (final e in _r.escenas)
        if (e.posicion != escena.posicion && !ocupados.contains(e.posicion)) e,
    ];
    if (opciones.isEmpty) {
      _snack(_r.escenas.length < 2
          ? 'Sube al menos otro escenario para poder conectarlos.'
          : 'Este escenario ya tiene flecha hacia todos los demás.');
      return;
    }
    final elegido = await showDialog<(int, String)>(
      context: context,
      builder: (_) => _DialogoFlecha(opciones: opciones),
    );
    if (elegido == null) return;
    await _guardarFlechas(escena, [
      ...escena.enlaces,
      Enlace360(destino: elegido.$1, yaw: _normalizarYaw(yaw), pitch: double.parse(pitch.toStringAsFixed(1)), etiqueta: elegido.$2),
    ]);
  }

  Future<void> _editarFlecha(EnlaceVisor flecha) async {
    final escena = _sel;
    if (escena == null) return;
    Escena360? destino;
    for (final e in _r.escenas) {
      if (e.id == flecha.destinoId) destino = e;
    }
    if (destino == null) return;
    final enlace = escena.enlaces.firstWhere((l) => l.destino == destino!.posicion);
    final res = await showDialog<_EdicionFlecha>(
      context: context,
      builder: (_) => _DialogoEditarFlecha(destino: destino!, etiqueta: enlace.etiqueta),
    );
    if (res == null) return;
    await _guardarFlechas(escena, [
      for (final l in escena.enlaces)
        if (l.destino != enlace.destino)
          l
        else if (!res.eliminar)
          Enlace360(destino: l.destino, yaw: l.yaw, pitch: l.pitch, etiqueta: res.etiqueta),
    ]);
  }

  Future<void> _quitarFlecha(Escena360 escena, Enlace360 enlace) =>
      _guardarFlechas(escena, [for (final l in escena.enlaces) if (l.destino != enlace.destino) l]);

  /// Primera versión rápida de las flechas: cada escenario con el anterior
  /// (atrás) y el siguiente (al frente, hacia su vista inicial). Las que ya
  /// existen no se tocan; luego el admin acomoda cada flecha donde va.
  Future<void> _conectarEnOrden() async {
    final escenas = [..._r.escenas]..sort((a, b) => a.posicion.compareTo(b.posicion));
    if (escenas.length < 2) {
      _snack('Sube al menos dos escenarios para conectarlos.');
      return;
    }
    final ok = await _confirmar(
      context,
      titulo: 'Conectar en orden',
      mensaje: 'Se conectarán los escenarios en orden: 1 ↔ 2 ↔ 3 … ↔ ${escenas.length}.',
      accion: 'Conectar',
      peligro: false,
    );
    if (!ok) return;
    await _accion((token) async {
      for (var i = 0; i < escenas.length; i++) {
        final e = escenas[i];
        final existentes = e.enlaces.map((l) => l.destino).toSet();
        final nuevas = <Enlace360>[
          if (i + 1 < escenas.length && !existentes.contains(escenas[i + 1].posicion))
            Enlace360(destino: escenas[i + 1].posicion, yaw: _normalizarYaw(e.yawInicial), pitch: -20),
          if (i > 0 && !existentes.contains(escenas[i - 1].posicion))
            Enlace360(destino: escenas[i - 1].posicion, yaw: _normalizarYaw(e.yawInicial + 180), pitch: -20),
        ];
        if (nuevas.isEmpty) continue;
        _conEscena(await widget.service.setEnlaces(token, _r.id, e.posicion, [...e.enlaces, ...nuevas]));
      }
      _snack('Listo: revisa cada escenario y acomoda las flechas.');
    }, 'No se pudieron conectar los escenarios');
  }

  // --- UI -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final r = _r;
    final bloqueado = _ocupado || _subiendo;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton.icon(
          onPressed: bloqueado ? null : widget.onBack,
          icon: Icon(Icons.arrow_back, size: 16, color: AppColors.slate300),
          label: Text('Recorridos', style: TextStyle(color: AppColors.slate300)),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.lg,
          runSpacing: AppSpacing.md,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.titulo, style: AppTypography.h1),
                const SizedBox(height: 4),
                Text(
                  '${r.nombre} · ${widget.lugarNombre ?? 'General del destino'}',
                  style: AppTypography.body,
                ),
              ],
            ),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                DsButton(
                  label: 'Editar datos',
                  icon: Icons.edit_outlined,
                  variant: DsButtonVariant.ghost,
                  onPressed: bloqueado ? null : widget.onEditarDatos,
                ),
                if (r.escenas.length > 1)
                  DsButton(
                    label: 'Conectar en orden',
                    icon: Icons.alt_route,
                    variant: DsButtonVariant.secondary,
                    accent: AppColors.adminViolet,
                    onPressed: bloqueado ? null : _conectarEnOrden,
                  ),
                DsButton(
                  label: 'Subir escenarios',
                  icon: Icons.add_photo_alternate_outlined,
                  variant: DsButtonVariant.primary,
                  accent: AppColors.adminViolet,
                  onPressed: bloqueado || r.escenas.length >= maxEscenarios ? null : _subirVarios,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        if (_subidaTotal > 0 && (_subiendo || _erroresSubida.isNotEmpty)) ...[
          const SizedBox(height: AppSpacing.md),
          _ProgresoSubida(
            total: _subidaTotal,
            hechas: _subidaHechas,
            archivo: _subidaArchivo,
            errores: _erroresSubida,
            onCerrar: _subiendo ? null : () => setState(() => _subidaTotal = 0),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        if (r.escenas.isEmpty)
          _SinEscenarios(onSubir: bloqueado ? null : _subirVarios)
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final visor = _panelVisor();
              final cuadricula = _panelEscenarios(columnas: constraints.maxWidth >= 1040 ? 2 : 3);
              if (constraints.maxWidth >= 1040) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: visor),
                    const SizedBox(width: AppSpacing.lg),
                    SizedBox(width: 340, child: cuadricula),
                  ],
                );
              }
              return Column(children: [visor, const SizedBox(height: AppSpacing.lg), cuadricula]);
            },
          ),
      ],
    );
  }

  Widget _panelVisor() {
    final escena = _sel!;
    final r = _r;
    final porPosicion = {for (final e in r.escenas) e.posicion: e};

    return DsCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
            child: SizedBox(
              height: 460,
              child: Visor360(
                escenas: EscenaVisor.deRecorridoAdmin(r),
                escenaId: escena.id,
                onEscenaCambiada: _seleccionar,
                titulo: r.titulo,
                subtitulo: widget.lugarNombre,
                acento: AppColors.adminViolet,
                mostrarTira: false,
                controller: _visor,
                onTapPanorama: _colocando ? _agregarFlecha : null,
                onFlechaTocada: _colocando ? _editarFlecha : null,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: false, icon: Icon(Icons.visibility_outlined, size: 16), label: Text('Vista del turista')),
                        ButtonSegment(value: true, icon: Icon(Icons.add_location_alt_outlined, size: 16), label: Text('Colocar flechas')),
                      ],
                      selected: {_colocando},
                      onSelectionChanged: (s) => setState(() => _colocando = s.first),
                      style: ButtonStyle(
                        foregroundColor: WidgetStateProperty.resolveWith(
                          (states) => states.contains(WidgetState.selected) ? Colors.white : AppColors.slate300,
                        ),
                        backgroundColor: WidgetStateProperty.resolveWith(
                          (states) => states.contains(WidgetState.selected) ? AppColors.adminViolet : Colors.transparent,
                        ),
                      ),
                    ),
                    DsButton(
                      label: 'Fijar vista inicial aquí',
                      icon: Icons.center_focus_strong_outlined,
                      size: DsButtonSize.sm,
                      variant: DsButtonVariant.ghost,
                      onPressed: _ocupado ? null : () => _fijarVistaInicial(escena),
                    ),
                    if (_ocupado) SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.adminViolet)),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Align(
                  alignment: Alignment.centerLeft,
                  child: DsBadge(
                    text: 'Escenario ${escena.posicion}${escena.posicion == r.escenas.first.posicion ? ' · Entrada' : ''}',
                    tone: BadgeTone.info,
                    icon: Icons.threesixty,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Nombre del escenario',
                  icon: Icons.title,
                  controller: _tituloEscena,
                  hintText: 'Ej. Entrada, Palapas, Malecón',
                  accentColor: AppColors.adminViolet,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Descripción (opcional)',
                  icon: Icons.notes,
                  controller: _descripcionEscena,
                  maxLines: 2,
                  hintText: 'Ej. Vista hacia la bahía desde el malecón.',
                  accentColor: AppColors.adminViolet,
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    DsButton(
                      label: 'Guardar escenario',
                      icon: Icons.check,
                      size: DsButtonSize.sm,
                      variant: DsButtonVariant.primary,
                      accent: AppColors.adminViolet,
                      onPressed: _ocupado ? null : () => _guardarDatos(escena),
                    ),
                    DsButton(
                      label: 'Reemplazar foto',
                      icon: Icons.upload_outlined,
                      size: DsButtonSize.sm,
                      variant: DsButtonVariant.secondary,
                      accent: AppColors.adminViolet,
                      onPressed: _ocupado ? null : () => _reemplazarFoto(escena),
                    ),
                    DsButton(
                      label: 'Quitar escenario',
                      icon: Icons.delete_outline,
                      size: DsButtonSize.sm,
                      variant: DsButtonVariant.danger,
                      onPressed: _ocupado ? null : () => _quitar(escena),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('Flechas de este escenario', style: AppTypography.h3),
                const SizedBox(height: AppSpacing.sm),
                if (escena.enlaces.isEmpty)
                  Text(
                    'Sin flechas.',
                    style: AppTypography.bodySmall,
                  )
                else
                  for (final l in escena.enlaces)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Icon(Icons.arrow_forward, size: 16, color: AppColors.adminViolet),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              '${porPosicion[l.destino]?.nombre ?? 'Escenario ${l.destino}'}'
                              '${l.etiqueta.isEmpty ? '' : ' · "${l.etiqueta}"'}',
                              style: AppTypography.bodySmall.copyWith(color: AppColors.textPrimary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text('${l.yaw.round()}° · ${l.pitch.round()}°', style: AppTypography.caption),
                          IconButton(
                            tooltip: 'Quitar flecha',
                            visualDensity: VisualDensity.compact,
                            onPressed: _ocupado ? null : () => _quitarFlecha(escena, l),
                            icon: Icon(Icons.close, size: 16, color: AppColors.errorRed),
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

  Widget _panelEscenarios({required int columnas}) {
    final r = _r;
    final sel = _sel;
    final entrada = r.escenas.first.posicion;
    return DsCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('Escenarios', style: AppTypography.h3),
              const Spacer(),
              Text('${r.escenas.length} / $maxEscenarios', style: AppTypography.caption),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          GridView.count(
            crossAxisCount: columnas,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
            childAspectRatio: 1.35,
            children: [
              for (final e in r.escenas)
                _TarjetaEscenario(
                  escena: e,
                  seleccionada: e.id == sel?.id,
                  entrada: e.posicion == entrada,
                  sinFlechas: r.escenas.length > 1 && e.enlaces.isEmpty,
                  onTap: () => _seleccionar(e.id),
                ),
              if (r.escenas.length < maxEscenarios)
                InkWell(
                  onTap: _ocupado || _subiendo ? null : _subirVarios,
                  borderRadius: BorderRadius.circular(AppRadius.button),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.button),
                      border: Border.all(color: AppColors.adminViolet.withValues(alpha: 0.4)),
                      color: AppColors.adminViolet.withValues(alpha: 0.05),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate_outlined, color: AppColors.adminViolet),
                        const SizedBox(height: 4),
                        Text('Agregar', style: TextStyle(color: AppColors.adminViolet, fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TarjetaEscenario extends StatelessWidget {
  final Escena360 escena;
  final bool seleccionada;
  final bool entrada;
  final bool sinFlechas;
  final VoidCallback onTap;

  const _TarjetaEscenario({
    required this.escena,
    required this.seleccionada,
    required this.entrada,
    required this.sinFlechas,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.button),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.button),
          border: Border.all(
            color: seleccionada ? AppColors.adminViolet : AppColors.borderSubtle,
            width: seleccionada ? 2.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    escena.miniaturaUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(Icons.broken_image_outlined, color: AppColors.slate500),
                  ),
                  Positioned(
                    left: 4,
                    top: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: entrada ? AppColors.adminViolet : Colors.black54,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        entrada ? '${escena.posicion} · Entrada' : '${escena.posicion}',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  if (sinFlechas)
                    Positioned(
                      right: 4,
                      top: 4,
                      child: Tooltip(
                        message: 'Sin flechas',
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(color: AppColors.amber, shape: BoxShape.circle),
                          child: const Icon(Icons.priority_high, size: 12, color: Colors.black),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Container(
              color: AppColors.panelNavySoft,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      escena.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Icon(Icons.alt_route, size: 12, color: AppColors.slate400),
                  const SizedBox(width: 2),
                  Text('${escena.enlaces.length}', style: AppTypography.caption),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SinEscenarios extends StatelessWidget {
  final VoidCallback? onSubir;

  const _SinEscenarios({required this.onSubir});

  @override
  Widget build(BuildContext context) {
    return DsCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Column(
          children: [
            Icon(Icons.threesixty, size: 48, color: AppColors.adminViolet),
            const SizedBox(height: AppSpacing.md),
            Text('Sube los escenarios del recorrido', style: AppTypography.h2),
            const SizedBox(height: AppSpacing.lg),
            DsButton(
              label: 'Elegir fotos 360°',
              icon: Icons.add_photo_alternate_outlined,
              variant: DsButtonVariant.primary,
              accent: AppColors.adminViolet,
              onPressed: onSubir,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgresoSubida extends StatelessWidget {
  final int total;
  final int hechas;
  final String? archivo;
  final List<String> errores;
  final VoidCallback? onCerrar;

  const _ProgresoSubida({required this.total, required this.hechas, required this.archivo, required this.errores, this.onCerrar});

  @override
  Widget build(BuildContext context) {
    final terminado = hechas >= total;
    return DsCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  terminado ? 'Subida terminada: $hechas de $total' : 'Subiendo y optimizando ${hechas + 1} de $total · ${archivo ?? ''}',
                  style: AppTypography.bodySmall.copyWith(color: AppColors.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (onCerrar != null)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: onCerrar,
                  icon: Icon(Icons.close, size: 16, color: AppColors.slate400),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          LinearProgressIndicator(
            value: total == 0 ? 0 : hechas / total,
            color: AppColors.adminViolet,
            backgroundColor: AppColors.overlay(0.08),
          ),
          for (final e in errores) ...[
            const SizedBox(height: 4),
            Text('✕ $e', style: TextStyle(color: AppColors.errorRed, fontSize: 12)),
          ],
        ],
      ),
    );
  }
}

/// Destino y texto de una flecha nueva.
class _DialogoFlecha extends StatefulWidget {
  final List<Escena360> opciones;

  const _DialogoFlecha({required this.opciones});

  @override
  State<_DialogoFlecha> createState() => _DialogoFlechaState();
}

class _DialogoFlechaState extends State<_DialogoFlecha> {
  late int _destino = widget.opciones.first.posicion;
  final _etiqueta = TextEditingController();

  @override
  void dispose() {
    _etiqueta.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.panelNavySoft,
      title: Text('Nueva flecha', style: TextStyle(color: AppColors.textPrimary)),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('¿A qué escenario lleva?', style: AppTypography.bodySmall),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<int>(
              initialValue: _destino,
              isExpanded: true,
              dropdownColor: AppColors.panelNavySoft,
              style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
              items: [
                for (final e in widget.opciones)
                  DropdownMenuItem(value: e.posicion, child: Text('${e.posicion}. ${e.nombre}', overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (v) => setState(() => _destino = v ?? _destino),
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Texto de la flecha (opcional)',
              icon: Icons.label_outline,
              controller: _etiqueta,
              hintText: 'Ej. Ir a las palapas',
              accentColor: AppColors.adminViolet,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancelar', style: TextStyle(color: AppColors.slate400)),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop((_destino, _etiqueta.text.trim())),
          child: Text('Agregar flecha', style: TextStyle(color: AppColors.adminViolet)),
        ),
      ],
    );
  }
}

class _EdicionFlecha {
  final String etiqueta;
  final bool eliminar;

  const _EdicionFlecha(this.etiqueta, {this.eliminar = false});
}

class _DialogoEditarFlecha extends StatefulWidget {
  final Escena360 destino;
  final String etiqueta;

  const _DialogoEditarFlecha({required this.destino, required this.etiqueta});

  @override
  State<_DialogoEditarFlecha> createState() => _DialogoEditarFlechaState();
}

class _DialogoEditarFlechaState extends State<_DialogoEditarFlecha> {
  late final _etiqueta = TextEditingController(text: widget.etiqueta);

  @override
  void dispose() {
    _etiqueta.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.panelNavySoft,
      title: Text('Flecha a "${widget.destino.nombre}"', style: TextStyle(color: AppColors.textPrimary)),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(
              label: 'Texto de la flecha',
              icon: Icons.label_outline,
              controller: _etiqueta,
              hintText: 'Ej. Ir a las palapas',
              accentColor: AppColors.adminViolet,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(const _EdicionFlecha('', eliminar: true)),
          child: Text('Quitar flecha', style: TextStyle(color: AppColors.errorRed)),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancelar', style: TextStyle(color: AppColors.slate400)),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_EdicionFlecha(_etiqueta.text.trim())),
          child: Text('Guardar', style: TextStyle(color: AppColors.adminViolet)),
        ),
      ],
    );
  }
}
