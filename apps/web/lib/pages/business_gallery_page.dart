import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/business_profile.dart';
import '../services/auth_service.dart';
import '../services/image_picker_service.dart';
import '../services/session_storage.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/cover_image.dart';
import '../widgets/themed_builder.dart';

class BusinessGalleryPage extends StatefulWidget {
  final BusinessProfile business;

  /// Solo para pruebas: permite usar un servicio con un cliente HTTP falso.
  final AuthService? authService;

  const BusinessGalleryPage({super.key, required this.business, this.authService});

  @override
  State<BusinessGalleryPage> createState() => _BusinessGalleryPageState();
}

class _PendingImage {
  final Uint8List bytes;
  final String name;
  const _PendingImage(this.bytes, this.name);
}

/// La galería ahora funciona como borrador (Error 5.4): agregar o quitar fotos
/// solo cambia la vista previa; nada se sube ni se borra en el servidor hasta
/// tocar "Guardar cambios". "Cancelar" (o salir con atrás) descarta todo.
/// Antes cada foto se subía al elegirla y quedaba aplicada aunque el usuario
/// no guardara.
class _BusinessGalleryPageState extends State<BusinessGalleryPage> {
  late final AuthService _authService = widget.authService ?? AuthService();
  final List<_PendingImage> _pendingAdds = [];
  final Set<String> _pendingRemovals = {};
  bool _isSaving = false;
  String? _error;

  /// true si algo ya se guardó en el servidor (aunque luego algo fallara),
  /// para que la pantalla anterior refresque.
  bool _changed = false;

  bool get _isDirty => _pendingAdds.isNotEmpty || _pendingRemovals.isNotEmpty;

  Future<void> _addImage() async {
    final picked = await ImagePickerService.pick();
    if (picked == null || !mounted) return;

    setState(() {
      _pendingAdds.add(_PendingImage(picked.bytes, picked.name));
      _error = null;
    });
  }

  void _removeSaved(String url) => setState(() => _pendingRemovals.add(url));

  void _removePending(_PendingImage img) => setState(() => _pendingAdds.remove(img));

  Future<void> _save() async {
    final token = SessionStorage.token;
    if (token == null) {
      setState(() => _error = 'Tu sesión expiró, vuelve a iniciar sesión');
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      for (final url in _pendingRemovals.toList()) {
        final updated = await _authService.deleteGaleriaImage(token, widget.business.id, url);
        widget.business.gallery = _galeriaOf(updated) ?? widget.business.gallery;
        _pendingRemovals.remove(url);
        _changed = true;
      }
      for (final img in _pendingAdds.toList()) {
        final updated = await _authService.uploadGaleriaImage(token, widget.business.id, img.bytes, img.name);
        widget.business.gallery = _galeriaOf(updated) ?? widget.business.gallery;
        _pendingAdds.remove(img);
        _changed = true;
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (err) {
      // Lo que alcanzó a guardarse ya salió de las listas de pendientes; lo
      // que falló sigue ahí para reintentar.
      if (mounted) {
        setState(() => _error = err is AuthError ? err.message : 'No se pudieron guardar todos los cambios');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// Pregunta antes de descartar cambios sin guardar.
  Future<bool> _confirmDiscard() async {
    if (!_isDirty) return true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.panelNavySoft,
        title: Text('Descartar cambios', style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          'Tienes cambios en la galería sin guardar. Si sales, se perderán.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Seguir editando', style: TextStyle(color: AppColors.slate400)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Descartar', style: TextStyle(color: AppColors.errorRed)),
          ),
        ],
      ),
    );
    return discard == true;
  }

  Future<void> _cancel() async {
    if (_isSaving) return;
    if (await _confirmDiscard() && mounted) Navigator.of(context).pop(_changed);
  }

  List<String>? _galeriaOf(AuthUser user) {
    final matches = user.negocios.where((n) => n.id == widget.business.id);
    return matches.isEmpty ? null : matches.first.galeria;
  }

  @override
  Widget build(BuildContext context) => ThemedBuilder(builder: _buildScaffold);

  Widget _buildScaffold(BuildContext context) {
    // El botón "atrás" del sistema pasa por la misma confirmación.
    return PopScope<Object?>(
      canPop: !_isDirty && !_isSaving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancel();
      },
      child: Scaffold(
        backgroundColor: AppColors.panelNavy,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _cancel,
                        icon: Icon(Icons.arrow_back, size: 15, color: AppColors.slate400),
                        label: Text('Volver a mi negocio', style: TextStyle(color: AppColors.slate400, fontSize: 13)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('Galería de fotos', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 24)),
                    const SizedBox(height: 4),
                    Text(
                      'Sube y organiza las fotos que verán los visitantes en el mapa.',
                      style: TextStyle(color: AppColors.slate400, fontSize: 14),
                    ),
                    const SizedBox(height: 24),
                    if (_error != null) ...[
                      Text(_error!, style: TextStyle(color: AppColors.errorRed, fontSize: 13)),
                      const SizedBox(height: 12),
                    ],
                    _buildGrid(),
                    if (_isDirty) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Los cambios se aplicarán al tocar "Guardar cambios".',
                        style: TextStyle(color: AppColors.slate400, fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: AppButton(
                            variant: AppButtonVariant.ghost,
                            onPressed: _isSaving ? null : _cancel,
                            child: const Text('Cancelar'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppButton(
                            backgroundColor: AppColors.businessOrange,
                            foregroundColor: Colors.white,
                            onPressed: (_isSaving || !_isDirty) ? null : _save,
                            child: Text(_isSaving ? 'Guardando...' : 'Guardar cambios'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 480 ? 2 : 3;
        final tileSize = (constraints.maxWidth - (columns - 1) * 10) / columns;
        final visibles = widget.business.gallery.where((url) => !_pendingRemovals.contains(url));

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            ...visibles.map((url) => _GalleryTile(
                  image: CoverImage(source: url),
                  size: tileSize,
                  isBusy: _isSaving,
                  onDelete: () => _removeSaved(url),
                )),
            ..._pendingAdds.map((img) => _GalleryTile(
                  image: Image.memory(img.bytes, fit: BoxFit.cover),
                  size: tileSize,
                  isBusy: _isSaving,
                  isPending: true,
                  onDelete: () => _removePending(img),
                )),
            _AddTile(size: tileSize, isUploading: false, onTap: _isSaving ? null : _addImage),
          ],
        );
      },
    );
  }
}

class _GalleryTile extends StatelessWidget {
  final Widget image;
  final double size;
  final bool isBusy;
  final bool isPending;
  final VoidCallback onDelete;

  const _GalleryTile({
    required this.image,
    required this.size,
    required this.isBusy,
    required this.onDelete,
    this.isPending = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            image,
            if (isPending)
              Positioned(
                left: 6,
                bottom: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(6)),
                  child: const Text('Sin guardar', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600)),
                ),
              ),
            if (!isBusy)
              Positioned(
                right: 6,
                top: 6,
                child: GestureDetector(
                  onTap: onDelete,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), shape: BoxShape.circle),
                    child: const Icon(Icons.close, size: 15, color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  final double size;
  final bool isUploading;
  final VoidCallback? onTap;

  const _AddTile({required this.size, required this.isUploading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.overlay(0.15)),
        ),
        child: Center(
          child: isUploading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.businessOrange),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add, size: 18, color: AppColors.slate400),
                    const SizedBox(height: 2),
                    Text('Agregar', style: TextStyle(color: AppColors.slate400, fontSize: 9)),
                  ],
                ),
        ),
      ),
    );
  }
}
