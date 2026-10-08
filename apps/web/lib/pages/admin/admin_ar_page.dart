import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../services/ar_service.dart';
import '../../services/auth_service.dart';
import '../../services/session_storage.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin/ds_badge.dart';
import '../../widgets/admin/ds_button.dart';
import '../../widgets/admin/ds_card.dart';
import '../../widgets/admin/ds_states.dart';
import '../../widgets/app_text_field.dart';

/// Contenido de la sección "Realidad aumentada" embebido en [AdminShell]:
/// alta, edición y baja de los marcadores que reconoce la cámara de la app
/// móvil. Lo que se guarda aquí lo descarga Unity al abrir la cámara, sin
/// publicar una versión nueva de la app.
class AdminArPage extends StatefulWidget {
  final AuthService authService;
  final ArService arService;

  AdminArPage({super.key, AuthService? authService, ArService? arService})
      : authService = authService ?? AuthService(),
        arService = arService ?? ArService();

  @override
  State<AdminArPage> createState() => _AdminArPageState();
}

class _AdminArPageState extends State<AdminArPage> {
  List<ArMarcador> _marcadores = [];
  List<NegocioSummary> _negocios = [];
  bool _loading = true;
  String? _error;
  final Set<String> _busy = {};

  // Formulario: abierto para alta (`_editing == null`) o para editar uno.
  bool _showForm = false;
  ArMarcador? _editing;

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
        widget.arService.listMarcadores(token),
        widget.authService.adminListNegocios(token),
      ]);
      if (!mounted) return;
      setState(() {
        _marcadores = results[0] as List<ArMarcador>;
        // Solo negocios aprobados: el endpoint público oculta los marcadores
        // de negocios pendientes/rechazados, así que ligarlos no serviría.
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

  void _openForm([ArMarcador? marcador]) {
    setState(() {
      _editing = marcador;
      _showForm = true;
    });
  }

  void _closeForm() => setState(() {
        _showForm = false;
        _editing = null;
      });

  void _onSaved(ArMarcador saved) {
    setState(() {
      final i = _marcadores.indexWhere((m) => m.id == saved.id);
      if (i >= 0) {
        _marcadores[i] = saved;
      } else {
        _marcadores = [saved, ..._marcadores];
      }
      _showForm = false;
      _editing = null;
    });
  }

  Future<void> _toggleActivo(ArMarcador marcador, bool activo) async {
    final token = SessionStorage.token;
    if (token == null) return;
    setState(() => _busy.add(marcador.id));
    try {
      final updated = await widget.arService.updateMarcador(token, marcador.id, {'activo': activo});
      if (!mounted) return;
      setState(() {
        final i = _marcadores.indexWhere((m) => m.id == updated.id);
        if (i >= 0) _marcadores[i] = updated;
      });
    } catch (err) {
      _snack(err is AuthError ? err.message : 'No se pudo actualizar el marcador');
    } finally {
      if (mounted) setState(() => _busy.remove(marcador.id));
    }
  }

  Future<void> _delete(ArMarcador marcador) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.panelNavySoft,
        title: Text('Eliminar marcador', style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          '"${marcador.nombre}" dejará de reconocerse en la app y se perderán sus estadísticas de escaneo. '
          'Si solo quieres ocultarlo un tiempo, mejor desactívalo.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
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
    if (confirmed != true) return;

    final token = SessionStorage.token;
    if (token == null) return;
    setState(() => _busy.add(marcador.id));
    try {
      await widget.arService.deleteMarcador(token, marcador.id);
      if (!mounted) return;
      setState(() {
        _marcadores.removeWhere((m) => m.id == marcador.id);
        if (_editing?.id == marcador.id) _closeForm();
      });
    } catch (err) {
      _snack(err is AuthError ? err.message : 'No se pudo eliminar el marcador');
    } finally {
      if (mounted) setState(() => _busy.remove(marcador.id));
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final activos = _marcadores.where((m) => m.activo).length;
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.adminViolet,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppSpacing.lg,
                runSpacing: AppSpacing.md,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Realidad aumentada', style: AppTypography.h1),
                      const SizedBox(height: 4),
                      Text(
                        _loading
                            ? 'Imágenes que reconoce la cámara de la app.'
                            : '${_marcadores.length} marcadores · $activos activos en la app',
                        style: AppTypography.body,
                      ),
                    ],
                  ),
                  if (!_showForm)
                    DsButton(
                      label: 'Nuevo marcador',
                      icon: Icons.add,
                      variant: DsButtonVariant.primary,
                      accent: AppColors.adminViolet,
                      onPressed: _loading ? null : () => _openForm(),
                    ),
                ],
              ),
              if (_showForm) ...[
                const SizedBox(height: AppSpacing.xl),
                _MarcadorForm(
                  // Cambiar de marcador reinicia el formulario (controllers nuevos).
                  key: ValueKey(_editing?.id ?? 'nuevo'),
                  marcador: _editing,
                  negocios: _negocios,
                  arService: widget.arService,
                  onCancel: _closeForm,
                  onSaved: _onSaved,
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              _buildList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_loading) return DsLoadingState(accent: AppColors.adminViolet);
    if (_error != null) return DsErrorState(message: _error!, onRetry: _load);
    if (_marcadores.isEmpty) {
      return const DsEmptyState(
        icon: Icons.view_in_ar_outlined,
        title: 'Sin marcadores',
        subtitle: 'Sube la primera imagen para que la cámara de la app pueda reconocerla.',
      );
    }
    return Column(
      children: _marcadores
          .map((m) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _MarcadorRow(
                  marcador: m,
                  busy: _busy.contains(m.id),
                  onToggle: (v) => _toggleActivo(m, v),
                  onEdit: () => _openForm(m),
                  onDelete: () => _delete(m),
                ),
              ))
          .toList(),
    );
  }
}

class _MarcadorForm extends StatefulWidget {
  final ArMarcador? marcador;
  final List<NegocioSummary> negocios;
  final ArService arService;
  final VoidCallback onCancel;
  final ValueChanged<ArMarcador> onSaved;

  const _MarcadorForm({
    super.key,
    required this.marcador,
    required this.negocios,
    required this.arService,
    required this.onCancel,
    required this.onSaved,
  });

  @override
  State<_MarcadorForm> createState() => _MarcadorFormState();
}

class _MarcadorFormState extends State<_MarcadorForm> {
  final _formKey = GlobalKey<FormState>();
  late final _nombre = TextEditingController(text: widget.marcador?.nombre);
  late final _titulo = TextEditingController(text: widget.marcador?.titulo);
  late final _texto = TextEditingController(text: widget.marcador?.texto);
  // Se captura en centímetros (lo que se mide con una regla); la API usa metros.
  late final _anchoCm = TextEditingController(
    text: widget.marcador?.anchoMetros == null ? '' : _formatCm(widget.marcador!.anchoMetros! * 100),
  );
  late String? _negocioId = widget.marcador?.negocioId;

  Uint8List? _imagen;
  String? _imagenNombre;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.marcador != null;

  static String _formatCm(double cm) => cm == cm.roundToDouble() ? cm.toInt().toString() : cm.toStringAsFixed(1);

  @override
  void dispose() {
    _nombre.dispose();
    _titulo.dispose();
    _texto.dispose();
    _anchoCm.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    // Solo PNG/JPG: es lo que Unity puede decodificar en el celular (el
    // backend rechaza el resto de todos modos).
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg'],
      withData: true,
    );
    final file = result?.files.single;
    if (file == null || file.bytes == null) return;
    if (file.bytes!.length > 5 * 1024 * 1024) {
      setState(() => _error = 'La imagen pesa más de 5 MB');
      return;
    }
    setState(() {
      _imagen = file.bytes;
      _imagenNombre = file.name;
      _error = null;
    });
  }

  double? _anchoMetros() {
    final raw = _anchoCm.text.trim().replaceAll(',', '.');
    if (raw.isEmpty) return null;
    final cm = double.tryParse(raw);
    return cm == null ? null : cm / 100;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_isEdit && _imagen == null) {
      setState(() => _error = 'Selecciona la imagen del marcador');
      return;
    }
    final token = SessionStorage.token;
    if (token == null) return;

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      ArMarcador saved;
      if (_isEdit) {
        saved = await widget.arService.updateMarcador(token, widget.marcador!.id, {
          'nombre': _nombre.text.trim().toLowerCase(),
          'titulo': _titulo.text.trim(),
          'texto': _texto.text.trim(),
          'anchoMetros': _anchoMetros(),
          'negocioId': _negocioId,
        });
        if (_imagen != null) {
          saved = await widget.arService.replaceImagen(token, saved.id, _imagen!, _imagenNombre!);
        }
      } else {
        saved = await widget.arService.createMarcador(
          token,
          imagen: _imagen!,
          filename: _imagenNombre!,
          nombre: _nombre.text.trim().toLowerCase(),
          titulo: _titulo.text.trim(),
          texto: _texto.text.trim(),
          anchoMetros: _anchoMetros(),
          negocioId: _negocioId,
        );
      }
      if (!mounted) return;
      widget.onSaved(saved);
    } catch (err) {
      if (!mounted) return;
      setState(() => _error = err is AuthError ? err.message : 'No se pudo guardar el marcador');
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
              _isEdit ? 'EDITAR MARCADOR' : 'NUEVO MARCADOR',
              style: AppTypography.h3,
            ),
            const SizedBox(height: AppSpacing.md),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 620;
                final imagePicker = _buildImagePicker();
                final fields = _buildFields();
                if (!wide) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [imagePicker, const SizedBox(height: AppSpacing.lg), fields],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 220, child: imagePicker),
                    const SizedBox(width: AppSpacing.xl),
                    Expanded(child: fields),
                  ],
                );
              },
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
                  label: _saving ? 'Guardando...' : (_isEdit ? 'Guardar cambios' : 'Crear marcador'),
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

  Widget _buildImagePicker() {
    final Widget preview;
    if (_imagen != null) {
      preview = Image.memory(_imagen!, fit: BoxFit.contain);
    } else if (widget.marcador != null) {
      preview = Image.network(widget.marcador!.imagenUrl, fit: BoxFit.contain);
    } else {
      preview = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_photo_alternate_outlined, size: 32, color: AppColors.slate400),
          const SizedBox(height: AppSpacing.sm),
          Text('PNG o JPG, máx. 5 MB', style: AppTypography.bodySmall),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Imagen del marcador', style: TextStyle(color: AppColors.slate300, fontSize: 14)),
        const SizedBox(height: 8),
        AspectRatio(
          aspectRatio: 1,
          child: Material(
            color: AppColors.panelNavySoft,
            borderRadius: BorderRadius.circular(AppRadius.button),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: _saving ? null : _pickImage,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.button),
                  border: Border.all(color: AppColors.overlay(0.1)),
                ),
                child: preview,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        DsButton(
          label: _imagen != null || _isEdit ? 'Cambiar imagen' : 'Elegir imagen',
          icon: Icons.upload_outlined,
          size: DsButtonSize.sm,
          onPressed: _saving ? null : _pickImage,
        ),
      ],
    );
  }

  Widget _buildFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
          label: 'Identificador del marcador',
          icon: Icons.label_outline,
          controller: _nombre,
          hintText: 'Ej. gaviota_01',
          accentColor: AppColors.adminViolet,
          validator: _validarNombre,
        ),
        const SizedBox(height: 4),
        Text(
          'Único. Es el "nombre" con el que la app de RA reconoce esta imagen: '
          'solo minúsculas, números, _ o -.',
          style: AppTypography.caption,
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          label: 'Título que verá el turista',
          icon: Icons.title,
          controller: _titulo,
          hintText: 'Ej. Gaviota patiamarilla',
          accentColor: AppColors.adminViolet,
          validator: (v) => _required(v, 80),
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          label: 'Información',
          icon: Icons.notes,
          controller: _texto,
          maxLines: 4,
          hintText: 'Texto que aparece flotando sobre la imagen (máx. 500 caracteres)',
          accentColor: AppColors.adminViolet,
          validator: (v) => _required(v, 500),
        ),
        const SizedBox(height: 4),
        Text(
          'En la cámara se muestra el título y, debajo, esta información.',
          style: AppTypography.caption,
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          label: 'Ancho real impreso (cm, opcional)',
          icon: Icons.straighten,
          controller: _anchoCm,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          hintText: 'Ej. 30',
          accentColor: AppColors.adminViolet,
          validator: (v) {
            final raw = (v ?? '').trim().replaceAll(',', '.');
            if (raw.isEmpty) return null;
            final cm = double.tryParse(raw);
            if (cm == null || cm <= 0 || cm > 2000) return 'Ingresa un número entre 1 y 2000';
            return null;
          },
        ),
        const SizedBox(height: AppSpacing.md),
        Text('Negocio (opcional)', style: TextStyle(color: AppColors.slate300, fontSize: 14)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String?>(
          initialValue: widget.negocios.any((n) => n.id == _negocioId) ? _negocioId : null,
          isExpanded: true,
          dropdownColor: AppColors.panelNavySoft,
          style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            prefixIcon: Icon(Icons.apartment_outlined, size: 18, color: AppColors.slate500),
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
      ],
    );
  }

  // Mismo formato que valida el backend (nombreSchema en ar.controller.ts).
  static final _nombreValido = RegExp(r'^[a-z0-9_-]+$');

  String? _validarNombre(String? v) {
    final text = v?.trim().toLowerCase() ?? '';
    if (text.isEmpty) return 'Campo requerido';
    if (text.length > 60) return 'Máximo 60 caracteres';
    if (!_nombreValido.hasMatch(text)) return 'Solo minúsculas, números, _ o - (ej. gaviota_01)';
    return null;
  }

  String? _required(String? v, int max) {
    final text = v?.trim() ?? '';
    if (text.isEmpty) return 'Campo requerido';
    if (text.length > max) return 'Máximo $max caracteres';
    return null;
  }
}

class _MarcadorRow extends StatelessWidget {
  final ArMarcador marcador;
  final bool busy;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _MarcadorRow({
    required this.marcador,
    required this.busy,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: marcador.activo ? 1 : 0.6,
      child: DsCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.button),
              child: Container(
                width: 64,
                height: 64,
                color: AppColors.panelNavySoft,
                child: Image.network(
                  marcador.imagenUrl,
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
                    marcador.titulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  Text(marcador.nombre, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.bodySmall),
                  const SizedBox(height: 4),
                  Text(
                    marcador.texto,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySmall.copyWith(color: AppColors.slate400),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      DsBadge(
                        text: marcador.negocioNombre ?? 'General',
                        tone: marcador.negocioNombre != null ? BadgeTone.info : BadgeTone.neutral,
                        icon: marcador.negocioNombre != null ? Icons.apartment_outlined : Icons.public,
                      ),
                      DsBadge(
                        text: '${marcador.escaneos} ${marcador.escaneos == 1 ? 'escaneo' : 'escaneos'}',
                        tone: BadgeTone.success,
                        icon: Icons.photo_camera_outlined,
                      ),
                      if (!marcador.activo) const DsBadge(text: 'Oculto', tone: BadgeTone.warning),
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
                    message: marcador.activo ? 'Visible en la app' : 'Oculto en la app',
                    child: Switch(
                      value: marcador.activo,
                      onChanged: onToggle,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Editar',
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
