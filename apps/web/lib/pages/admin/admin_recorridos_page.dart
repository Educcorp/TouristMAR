import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/recorridos_service.dart';
import '../../services/session_storage.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin/ds_badge.dart';
import '../../widgets/admin/ds_button.dart';
import '../../widgets/admin/ds_card.dart';
import '../../widgets/admin/ds_states.dart';
import '../../widgets/app_text_field.dart';

/// Mismo límite que multer en recorridos.routes.ts.
const _maxMb = 30;

String _formatMb(int bytes) => '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';

/// Contenido de la sección "Recorridos 360°" embebido en [AdminShell]: alta,
/// edición y baja de los recorridos y sus 3 fotos 360°. Lo que se
/// guarda aquí lo descarga Unity desde `GET /api/recorridos`, sin publicar
/// una versión nueva de la app.
class AdminRecorridosPage extends StatefulWidget {
  final AuthService authService;
  final RecorridosService recorridosService;

  AdminRecorridosPage({super.key, AuthService? authService, RecorridosService? recorridosService})
      : authService = authService ?? AuthService(),
        recorridosService = recorridosService ?? RecorridosService();

  @override
  State<AdminRecorridosPage> createState() => _AdminRecorridosPageState();
}

class _AdminRecorridosPageState extends State<AdminRecorridosPage> {
  List<Recorrido360> _recorridos = [];
  List<NegocioSummary> _negocios = [];
  bool _loading = true;
  String? _error;
  final Set<String> _busy = {};

  // Formulario de datos: abierto para alta (`_editing == null`) o edición.
  bool _showForm = false;
  Recorrido360? _editing;

  /// Recorrido cuyas escenas se están editando (vista de detalle).
  String? _abiertoId;

  Recorrido360? get _abierto {
    for (final r in _recorridos) {
      if (r.id == _abiertoId) return r;
    }
    return null;
  }

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
      final results = await Future.wait([
        widget.recorridosService.listRecorridos(token),
        widget.authService.adminListNegocios(token),
      ]);
      if (!mounted) return;
      setState(() {
        _recorridos = results[0] as List<Recorrido360>;
        // Solo negocios aprobados: el endpoint público oculta los recorridos
        // de negocios pendientes/rechazados.
        _negocios = (results[1] as List<NegocioSummary>).where((n) => n.aprobado).toList()
          ..sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
      });
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
  }

  void _onSaved(Recorrido360 saved) {
    final esNuevo = !_recorridos.any((r) => r.id == saved.id);
    _replace(saved);
    setState(() {
      _showForm = false;
      _editing = null;
      // Recién creado: directo a subir sus fotos.
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
      mensaje: '"${recorrido.titulo}" y sus fotos dejarán de estar en la app. '
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
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.adminViolet,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (abierto != null && !_showForm)
                _EscenasEditor(
                  key: ValueKey(abierto.id),
                  recorrido: abierto,
                  service: widget.recorridosService,
                  onChanged: _replace,
                  onBack: () => setState(() => _abiertoId = null),
                  onEditarDatos: () => _openForm(abierto),
                )
              else
                ..._buildLista(),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildLista() {
    final publicados = _recorridos.where((r) => r.publicado).length;
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
              Text('Recorridos 360°', style: AppTypography.h1),
              const SizedBox(height: 4),
              Text(
                _loading
                    ? 'Fotos 360° que el turista recorre desde la app.'
                    : '${_recorridos.length} recorridos · $publicados visibles en la app',
                style: AppTypography.body,
              ),
            ],
          ),
          if (!_showForm)
            DsButton(
              label: 'Nuevo recorrido 360°',
              icon: Icons.add,
              variant: DsButtonVariant.primary,
              accent: AppColors.adminViolet,
              onPressed: _loading ? null : () => _openForm(),
            ),
        ],
      ),
      if (_showForm) ...[
        const SizedBox(height: AppSpacing.xl),
        _RecorridoForm(
          key: ValueKey(_editing?.id ?? 'nuevo'),
          recorrido: _editing,
          negocios: _negocios,
          service: widget.recorridosService,
          onCancel: _closeForm,
          onSaved: _onSaved,
        ),
      ],
      const SizedBox(height: AppSpacing.xl),
      _buildList(),
    ];
  }

  Widget _buildList() {
    if (_loading) return DsLoadingState(accent: AppColors.adminViolet);
    if (_error != null) return DsErrorState(message: _error!, onRetry: _load);
    if (_recorridos.isEmpty) {
      return const DsEmptyState(
        icon: Icons.threesixty,
        title: 'Sin recorridos 360°',
        subtitle: 'Crea el primero y sube sus 3 fotos 360° para que el turista pueda recorrer el lugar.',
      );
    }
    return Column(
      children: [
        for (final r in _recorridos)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _RecorridoRow(
              recorrido: r,
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

Future<bool> _confirmar(BuildContext context, {required String titulo, required String mensaje}) async {
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
          child: Text('Eliminar', style: TextStyle(color: AppColors.errorRed)),
        ),
      ],
    ),
  );
  return confirmed == true;
}

class _RecorridoForm extends StatefulWidget {
  final Recorrido360? recorrido;
  final List<NegocioSummary> negocios;
  final RecorridosService service;
  final VoidCallback onCancel;
  final ValueChanged<Recorrido360> onSaved;

  const _RecorridoForm({
    super.key,
    required this.recorrido,
    required this.negocios,
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
  late String? _negocioId = widget.recorrido?.negocioId;

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
              'negocioId': _negocioId,
            })
          : await widget.service.createRecorrido(
              token,
              nombre: nombre,
              titulo: _titulo.text.trim(),
              texto: _texto.text.trim(),
              negocioId: _negocioId,
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
              style: AppTypography.caption.copyWith(color: AppColors.adminViolet, letterSpacing: 1.5),
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Sitio', style: TextStyle(color: AppColors.slate300, fontSize: 14)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String?>(
              initialValue: widget.negocios.any((n) => n.id == _negocioId) ? _negocioId : null,
              isExpanded: true,
              dropdownColor: AppColors.panelNavySoft,
              style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.place_outlined, size: 18, color: AppColors.slate500),
                filled: true,
                fillColor: AppColors.panelNavySoft,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.overlay(0.1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.adminViolet),
                ),
              ),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('General del destino (sin negocio)')),
                ...widget.negocios.map(
                  (n) => DropdownMenuItem<String?>(value: n.id, child: Text(n.nombre, overflow: TextOverflow.ellipsis)),
                ),
              ],
              onChanged: _saving ? null : (v) => setState(() => _negocioId = v),
            ),
            const SizedBox(height: 4),
            Text(
              'Un negocio aprobado (su hotel, su restaurante) o un lugar general como un mirador o la bahía.',
              style: AppTypography.caption,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Identificador del recorrido',
              icon: Icons.label_outline,
              controller: _nombre,
              hintText: 'Ej. cerro_vigia_360',
              accentColor: AppColors.adminViolet,
              validator: _validarNombre,
            ),
            const SizedBox(height: 4),
            Text(
              'Único. Es el "nombre" con el que la app de RA identifica este recorrido: '
              'solo minúsculas, números, _ o -.',
              style: AppTypography.caption,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Título que verá el turista',
              icon: Icons.title,
              controller: _titulo,
              hintText: 'Ej. Cerro del Vigía',
              accentColor: AppColors.adminViolet,
              validator: (v) => _required(v, 80),
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Información',
              icon: Icons.notes,
              controller: _texto,
              maxLines: 4,
              hintText: 'Descripción del recorrido (máx. 500 caracteres)',
              accentColor: AppColors.adminViolet,
              validator: (v) => _required(v, 500),
            ),
            if (!_isEdit) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Después de crearlo subirás sus 3 fotos 360° (Foto 1, Foto 2 y Foto 3).',
                style: AppTypography.caption,
              ),
            ],
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
                  label: _saving ? 'Guardando...' : (_isEdit ? 'Guardar cambios' : 'Crear y subir fotos'),
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
  final bool busy;
  final ValueChanged<bool> onToggle;
  final VoidCallback onAbrir;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _RecorridoRow({
    required this.recorrido,
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
                        text: '${r.escenas.length} de $fotosPorRecorrido fotos',
                        tone: r.escenas.length == fotosPorRecorrido ? BadgeTone.success : BadgeTone.warning,
                        icon: Icons.photo_library_outlined,
                      ),
                      if (r.escenas.isNotEmpty)
                        DsBadge(text: _formatMb(r.pesoTotalBytes), tone: BadgeTone.neutral, icon: Icons.download_outlined),
                      if (!r.activo) const DsBadge(text: 'Oculto', tone: BadgeTone.warning),
                      if (r.activo && r.escenas.length < fotosPorRecorrido)
                        const DsBadge(text: 'Faltan fotos: no aparece en la app', tone: BadgeTone.warning),
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
                    child: Switch(value: r.activo, activeThumbColor: AppColors.adminViolet, onChanged: onToggle),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Fotos del recorrido',
                        onPressed: onAbrir,
                        icon: Icon(Icons.photo_library_outlined, size: 18, color: AppColors.adminViolet),
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

/// Vista de detalle de un recorrido: sus 3 casillas de foto. Cada foto se
/// sube en su casilla, así el orden (Foto 1 → 2 → 3) no depende de en qué
/// orden se suban.
class _EscenasEditor extends StatefulWidget {
  final Recorrido360 recorrido;
  final RecorridosService service;
  final ValueChanged<Recorrido360> onChanged;
  final VoidCallback onBack;
  final VoidCallback onEditarDatos;

  const _EscenasEditor({
    super.key,
    required this.recorrido,
    required this.service,
    required this.onChanged,
    required this.onBack,
    required this.onEditarDatos,
  });

  @override
  State<_EscenasEditor> createState() => _EscenasEditorState();
}

class _EscenasEditorState extends State<_EscenasEditor> {
  /// Casillas (1–3) con una subida o un borrado en curso.
  final Set<int> _busy = {};
  final Map<int, String> _errores = {};

  Recorrido360 get _r => widget.recorrido;

  void _conFoto(int posicion, Escena360? escena) {
    final escenas = [
      for (final e in _r.escenas)
        if (e.posicion != posicion) e,
      if (escena != null) escena,
    ]..sort((a, b) => a.posicion.compareTo(b.posicion));
    widget.onChanged(_r.copyWith(escenas: escenas));
  }

  Future<void> _subir(int posicion) async {
    // Como stream (no `withData`): el navegador no carga la foto completa
    // (hasta 30 MB) en memoria, la va leyendo mientras la sube.
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png'],
      withReadStream: true,
    );
    final file = result?.files.single;
    if (file == null) return;
    if (file.size > _maxMb * 1024 * 1024) {
      setState(() => _errores[posicion] = 'La foto pesa más de $_maxMb MB');
      return;
    }
    if (file.readStream == null) {
      setState(() => _errores[posicion] = 'No se pudo leer el archivo');
      return;
    }

    final token = SessionStorage.token;
    if (token == null) return;
    setState(() {
      _busy.add(posicion);
      _errores.remove(posicion);
    });
    try {
      final escena = await widget.service.setEscena(
        token,
        _r.id,
        posicion,
        bytes: file.readStream!,
        length: file.size,
        filename: file.name,
      );
      if (!mounted) return;
      _conFoto(posicion, escena);
    } catch (err) {
      if (!mounted) return;
      setState(() => _errores[posicion] = err is AuthError ? err.message : 'No se pudo subir la foto');
    } finally {
      if (mounted) setState(() => _busy.remove(posicion));
    }
  }

  Future<void> _quitar(int posicion) async {
    final confirmed = await _confirmar(
      context,
      titulo: 'Quitar Foto $posicion',
      mensaje: 'Mientras falte esta foto, el recorrido no aparecerá en la app.',
    );
    if (!confirmed) return;

    final token = SessionStorage.token;
    if (token == null) return;
    setState(() => _busy.add(posicion));
    try {
      await widget.service.deleteEscena(token, _r.id, posicion);
      if (!mounted) return;
      _conFoto(posicion, null);
    } catch (err) {
      if (!mounted) return;
      setState(() => _errores[posicion] = err is AuthError ? err.message : 'No se pudo quitar la foto');
    } finally {
      if (mounted) setState(() => _busy.remove(posicion));
    }
  }

  void _verCompleta(Escena360 escena) {
    // Solo aquí se descarga la foto grande (~1–2 MB), cuando se pide.
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppColors.panelNavySoft,
        insetPadding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.sm, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Foto ${escena.posicion} — ${escena.ancho}×${escena.alto} · ${_formatMb(escena.pesoBytes)}',
                      style: AppTypography.bodySmall,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, color: AppColors.slate400),
                  ),
                ],
              ),
            ),
            Flexible(
              child: InteractiveViewer(
                maxScale: 6,
                child: AspectRatio(
                  aspectRatio: 2,
                  child: Image.network(
                    escena.imagenUrl,
                    fit: BoxFit.cover,
                    loadingBuilder: (_, child, progress) => progress == null
                        ? child
                        : Center(child: CircularProgressIndicator(color: AppColors.adminViolet)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = _r;
    final ocupado = _busy.isNotEmpty;
    final faltan = fotosPorRecorrido - r.escenas.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton.icon(
          onPressed: ocupado ? null : widget.onBack,
          icon: Icon(Icons.arrow_back, size: 16, color: AppColors.slate300),
          label: Text('Recorridos 360°', style: TextStyle(color: AppColors.slate300)),
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
                  '${r.nombre} · ${r.negocioNombre ?? 'General del destino'}'
                  '${r.escenas.isEmpty ? '' : ' · ${_formatMb(r.pesoTotalBytes)} en total'}',
                  style: AppTypography.body,
                ),
              ],
            ),
            DsButton(
              label: 'Editar datos',
              icon: Icons.edit_outlined,
              variant: DsButtonVariant.ghost,
              onPressed: ocupado ? null : widget.onEditarDatos,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        if (faltan > 0)
          _Aviso(
            icon: Icons.info_outline,
            color: AppColors.amber,
            texto: 'Faltan $faltan ${faltan == 1 ? 'foto' : 'fotos'}: el recorrido aparecerá en la app '
                'cuando tenga las $fotosPorRecorrido.',
          )
        else
          _Aviso(
            icon: Icons.check_circle_outline,
            color: AppColors.emerald,
            texto: r.activo
                ? 'Completo: la app muestra las fotos en este orden (Foto 1 → Foto 2 → Foto 3).'
                : 'Completo, pero está oculto: actívalo en la lista para que aparezca en la app.',
          ),
        const SizedBox(height: AppSpacing.lg),
        LayoutBuilder(
          builder: (context, constraints) {
            final casillas = [
              for (var posicion = 1; posicion <= fotosPorRecorrido; posicion++)
                _CasillaFoto(
                  posicion: posicion,
                  escena: r.foto(posicion),
                  busy: _busy.contains(posicion),
                  error: _errores[posicion],
                  onSubir: () => _subir(posicion),
                  onQuitar: () => _quitar(posicion),
                  onVer: (e) => _verCompleta(e),
                ),
            ];
            if (constraints.maxWidth < 720) {
              return Column(
                children: [
                  for (final c in casillas) Padding(padding: const EdgeInsets.only(bottom: AppSpacing.md), child: c),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < casillas.length; i++) ...[
                  if (i > 0) const SizedBox(width: AppSpacing.md),
                  Expanded(child: casillas[i]),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        const _TipsFotos(),
      ],
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
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.button),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(texto, style: AppTypography.bodySmall.copyWith(color: AppColors.textPrimary))),
        ],
      ),
    );
  }
}

/// Qué foto sirve: el error más común es subir una foto normal o las tomas
/// sueltas de la cámara en vez de la panorámica 360° ya unida.
class _TipsFotos extends StatelessWidget {
  const _TipsFotos();

  @override
  Widget build(BuildContext context) {
    final style = AppTypography.bodySmall;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.amber.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.button),
        border: Border.all(color: AppColors.amber.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, size: 14, color: AppColors.amber),
              const SizedBox(width: 6),
              Text('Cada foto es una foto 360° completa',
                  style: style.copyWith(color: AppColors.amber, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 6),
          Text('• Equirectangular, el doble de ancho que de alto (2:1), p. ej. 6080×3040', style: style),
          Text('• Ya unida: la panorámica final, no las tomas sueltas de la cámara', style: style),
          Text('• JPG o PNG, máx. $_maxMb MB — se optimiza sola a 4096×2048 para el celular', style: style),
          Text('• El nombre del archivo no importa: el orden lo da la casilla', style: style),
        ],
      ),
    );
  }
}

class _CasillaFoto extends StatelessWidget {
  final int posicion;
  final Escena360? escena;
  final bool busy;
  final String? error;
  final VoidCallback onSubir;
  final VoidCallback onQuitar;
  final ValueChanged<Escena360> onVer;

  const _CasillaFoto({
    required this.posicion,
    required this.escena,
    required this.busy,
    required this.error,
    required this.onSubir,
    required this.onQuitar,
    required this.onVer,
  });

  @override
  Widget build(BuildContext context) {
    final e = escena;
    final Widget contenido;
    if (busy) {
      contenido = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.adminViolet)),
            const SizedBox(height: AppSpacing.sm),
            Text('Subiendo y optimizando…', style: AppTypography.caption),
          ],
        ),
      );
    } else if (e != null) {
      contenido = InkWell(
        onTap: () => onVer(e),
        child: Image.network(
          e.miniaturaUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Icon(Icons.broken_image_outlined, color: AppColors.slate500),
        ),
      );
    } else {
      contenido = InkWell(
        onTap: onSubir,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate_outlined, size: 28, color: AppColors.slate400),
            const SizedBox(height: 4),
            Text('Sin foto', style: AppTypography.caption),
          ],
        ),
      );
    }

    return DsCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('Foto $posicion', style: AppTypography.h3),
              const Spacer(),
              if (e != null) const DsBadge(text: 'Lista', tone: BadgeTone.success, icon: Icons.check),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.button),
            child: AspectRatio(
              aspectRatio: 2,
              child: Material(color: AppColors.panelNavySoft, child: contenido),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            e == null ? 'JPG o PNG 2:1' : '${e.ancho}×${e.alto} · ${_formatMb(e.pesoBytes)}',
            style: AppTypography.caption,
          ),
          if (error != null) ...[
            const SizedBox(height: 4),
            Text(error!, style: TextStyle(color: AppColors.errorRed, fontSize: 12)),
          ],
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              DsButton(
                label: e == null ? 'Subir Foto $posicion' : 'Reemplazar',
                icon: Icons.upload_outlined,
                size: DsButtonSize.sm,
                variant: e == null ? DsButtonVariant.primary : DsButtonVariant.secondary,
                accent: AppColors.adminViolet,
                onPressed: busy ? null : onSubir,
              ),
              if (e != null)
                DsButton(
                  label: 'Quitar',
                  icon: Icons.delete_outline,
                  size: DsButtonSize.sm,
                  variant: DsButtonVariant.danger,
                  onPressed: busy ? null : onQuitar,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
