import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/business_profile.dart';
import '../services/auth_service.dart';
import '../services/session_storage.dart';
import '../theme/app_theme.dart';
import '../widgets/cover_image.dart';

class BusinessGalleryPage extends StatefulWidget {
  final BusinessProfile business;

  const BusinessGalleryPage({super.key, required this.business});

  @override
  State<BusinessGalleryPage> createState() => _BusinessGalleryPageState();
}

class _BusinessGalleryPageState extends State<BusinessGalleryPage> {
  final _authService = AuthService();
  bool _isUploading = false;
  final Set<String> _deletingUrls = {};
  String? _error;
  bool _changed = false;

  Future<void> _addImage() async {
    final token = SessionStorage.token;
    if (token == null) {
      setState(() => _error = 'Tu sesión expiró, vuelve a iniciar sesión');
      return;
    }

    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    final file = result?.files.single;
    if (file == null || file.bytes == null) return;

    setState(() {
      _isUploading = true;
      _error = null;
    });

    try {
      final updated = await _authService.uploadGaleriaImage(token, file.bytes!, file.name);
      setState(() {
        widget.business.gallery = updated.negocio?.galeria ?? widget.business.gallery;
        _changed = true;
      });
    } catch (err) {
      setState(() => _error = err is AuthError ? err.message : 'No se pudo subir la imagen');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _confirmDelete(String url) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.panelNavySoft,
        title: Text('Eliminar foto', style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          'Esta foto se quitará de tu galería. Esta acción no se puede deshacer.',
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

    if (confirmed == true) _deleteImage(url);
  }

  Future<void> _deleteImage(String url) async {
    final token = SessionStorage.token;
    if (token == null) {
      setState(() => _error = 'Tu sesión expiró, vuelve a iniciar sesión');
      return;
    }

    setState(() {
      _deletingUrls.add(url);
      _error = null;
    });

    try {
      final updated = await _authService.deleteGaleriaImage(token, url);
      setState(() {
        widget.business.gallery = updated.negocio?.galeria ?? widget.business.gallery;
        _changed = true;
      });
    } catch (err) {
      setState(() => _error = err is AuthError ? err.message : 'No se pudo eliminar la imagen');
    } finally {
      if (mounted) setState(() => _deletingUrls.remove(url));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                      onPressed: () => Navigator.of(context).pop(_changed),
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
                ],
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

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            ...widget.business.gallery.map((url) => _GalleryTile(
                  url: url,
                  size: tileSize,
                  isDeleting: _deletingUrls.contains(url),
                  onDelete: () => _confirmDelete(url),
                )),
            _AddTile(size: tileSize, isUploading: _isUploading, onTap: _isUploading ? null : _addImage),
          ],
        );
      },
    );
  }
}

class _GalleryTile extends StatelessWidget {
  final String url;
  final double size;
  final bool isDeleting;
  final VoidCallback onDelete;

  const _GalleryTile({required this.url, required this.size, required this.isDeleting, required this.onDelete});

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
            CoverImage(source: url),
            if (isDeleting)
              DecoratedBox(
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.55)),
                child: const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
              )
            else
              Positioned(
                right: 6,
                top: 6,
                child: GestureDetector(
                  onTap: onDelete,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), shape: BoxShape.circle),
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
