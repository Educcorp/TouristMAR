import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/business_profile.dart';
import '../services/auth_service.dart';
import '../services/session_storage.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/app_text_field.dart';
import '../widgets/cover_image.dart';

class BusinessEditPage extends StatefulWidget {
  final BusinessProfile business;

  const BusinessEditPage({super.key, required this.business});

  @override
  State<BusinessEditPage> createState() => _BusinessEditPageState();
}

class _BusinessEditPageState extends State<BusinessEditPage> {
  late final _nameController = TextEditingController(text: widget.business.businessName);
  late final _categoryController = TextEditingController(text: widget.business.category);
  late final _descriptionController = TextEditingController(text: widget.business.description);
  late final _addressController = TextEditingController(text: widget.business.address);
  late final _phoneController = TextEditingController(text: widget.business.phone);
  late final _websiteController = TextEditingController(text: widget.business.website);
  late final _hoursController = TextEditingController(text: widget.business.hours);
  final _authService = AuthService();
  bool _isSaving = false;
  bool _isUploadingCover = false;
  final Set<String> _uploadingAssets = {};
  String? _error;

  Future<void> _uploadAsset(String kind) async {
    final token = SessionStorage.token;
    if (token == null) {
      setState(() => _error = 'Tu sesión expiró, vuelve a iniciar sesión');
      return;
    }

    final result = await FilePicker.platform.pickFiles(withData: true);
    final file = result?.files.single;
    if (file == null || file.bytes == null) return;

    setState(() {
      _uploadingAssets.add(kind);
      _error = null;
    });

    try {
      final updated = await _authService.uploadNegocioAsset(token, kind, file.bytes!, file.name);
      final negocio = updated.negocio;
      if (negocio != null) {
        setState(() {
          switch (kind) {
            case 'archivo360':
              widget.business.archivo360 = negocio.archivo360;
              break;
            case 'arMarcador':
              widget.business.arMarcador = negocio.arMarcador;
              break;
            case 'arGeo':
              widget.business.arGeo = negocio.arGeo;
              break;
          }
        });
      }
    } catch (err) {
      setState(() => _error = err is AuthError ? err.message : 'No se pudo subir el archivo');
    } finally {
      if (mounted) setState(() => _uploadingAssets.remove(kind));
    }
  }

  Future<void> _changeCover() async {
    final token = SessionStorage.token;
    if (token == null) {
      setState(() => _error = 'Tu sesión expiró, vuelve a iniciar sesión');
      return;
    }

    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    final file = result?.files.single;
    if (file == null || file.bytes == null) return;

    setState(() {
      _isUploadingCover = true;
      _error = null;
    });

    try {
      final updated = await _authService.uploadAvatar(token, file.bytes!, file.name);
      if (updated.negocio?.portada != null) {
        setState(() => widget.business.coverImage = updated.negocio!.portada!);
      }
    } catch (err) {
      setState(() => _error = err is AuthError ? err.message : 'No se pudo subir la portada');
    } finally {
      if (mounted) setState(() => _isUploadingCover = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _websiteController.dispose();
    _hoursController.dispose();
    super.dispose();
  }

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
      final updated = await _authService.updateProfile(token, {
        'nombre': _nameController.text.trim(),
        'categoria': _categoryController.text.trim(),
        'descripcion': _descriptionController.text.trim(),
        'direccion': _addressController.text.trim(),
        'telefono': _phoneController.text.trim(),
        'sitioWeb': _websiteController.text.trim(),
        'horario': _hoursController.text.trim(),
      });

      final business = widget.business;
      final negocio = updated.negocio;
      business.businessName = negocio?.nombre ?? _nameController.text.trim();
      business.category = negocio?.categoria ?? '';
      business.description = negocio?.descripcion ?? '';
      business.address = negocio?.direccion ?? '';
      business.phone = negocio?.telefono ?? '';
      business.website = negocio?.sitioWeb ?? '';
      business.hours = negocio?.horario ?? '';
      if (mounted) Navigator.of(context).pop(true);
    } catch (err) {
      setState(() => _error = err is AuthError ? err.message : 'No se pudo guardar el negocio');
    } finally {
      if (mounted) setState(() => _isSaving = false);
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
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => Navigator.of(context).pop(false),
                      icon: Icon(Icons.arrow_back, size: 15, color: AppColors.slate400),
                      label: Text('Volver a mi negocio', style: TextStyle(color: AppColors.slate400, fontSize: 13)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('Editar negocio', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 24)),
                  const SizedBox(height: 4),
                  Text(
                    'Actualiza la información visible a los visitantes en el mapa.',
                    style: TextStyle(color: AppColors.slate400, fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  GestureDetector(
                    onTap: _isUploadingCover ? null : _changeCover,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: SizedBox(
                        height: 140,
                        width: double.infinity,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CoverImage(source: widget.business.coverImage),
                            DecoratedBox(decoration: BoxDecoration(color: Colors.black.withOpacity(0.25))),
                            Center(
                              child: _isUploadingCover
                                  ? const CircularProgressIndicator(color: Colors.white)
                                  : const Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.camera_alt_outlined, color: Colors.white, size: 22),
                                        SizedBox(height: 6),
                                        Text('Cambiar foto de portada',
                                            style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  AppTextField(
                    label: 'Nombre del negocio',
                    icon: Icons.apartment,
                    controller: _nameController,
                    accentColor: AppColors.businessOrange,
                  ),
                  const SizedBox(height: 20),
                  AppTextField(
                    label: 'Categoría',
                    icon: Icons.local_offer_outlined,
                    controller: _categoryController,
                    hintText: 'Ej. Playa · Restaurante · Bar',
                    accentColor: AppColors.businessOrange,
                  ),
                  const SizedBox(height: 20),
                  Text('Descripción', style: TextStyle(color: AppColors.slate300, fontSize: 14)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _descriptionController,
                    maxLength: 350,
                    maxLines: 4,
                    onChanged: (_) => setState(() {}),
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Describe tu negocio o lugar turístico…',
                      hintStyle: TextStyle(color: AppColors.slate500),
                      filled: true,
                      fillColor: AppColors.panelNavySoft,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                      counterStyle: TextStyle(color: AppColors.slate500, fontSize: 11),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.overlay(0.1))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.overlay(0.1))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.businessOrange)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(20),
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.overlay(0.08)))),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'INFORMACIÓN DE CONTACTO',
                          style: TextStyle(color: AppColors.slate500, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1),
                        ),
                        const SizedBox(height: 16),
                        AppTextField(
                          label: 'Dirección',
                          icon: Icons.place_outlined,
                          controller: _addressController,
                          hintText: 'Calle, número, colonia…',
                          accentColor: AppColors.businessOrange,
                        ),
                        const SizedBox(height: 16),
                        AppTextField(
                          label: 'Teléfono',
                          icon: Icons.phone_outlined,
                          controller: _phoneController,
                          hintText: '+52 314 000 0000',
                          accentColor: AppColors.businessOrange,
                        ),
                        const SizedBox(height: 16),
                        AppTextField(
                          label: 'Sitio web',
                          icon: Icons.language,
                          controller: _websiteController,
                          hintText: 'miweb.com.mx',
                          accentColor: AppColors.businessOrange,
                        ),
                        const SizedBox(height: 16),
                        AppTextField(
                          label: 'Horario',
                          icon: Icons.schedule_outlined,
                          controller: _hoursController,
                          hintText: 'Lun – Dom: 9:00 am – 6:00 pm',
                          accentColor: AppColors.businessOrange,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(20),
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.overlay(0.08)))),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'RECURSOS AR Y 360°',
                          style: TextStyle(color: AppColors.slate500, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Sube el material para que tu lugar aparezca con foto 360° y realidad aumentada en el mapa.',
                          style: TextStyle(color: AppColors.slate400, fontSize: 12, height: 1.4),
                        ),
                        const SizedBox(height: 14),
                        _AssetUploadRow(
                          icon: Icons.threesixty,
                          label: 'Foto o video 360°',
                          hint: 'Imagen equirectangular o video inmersivo del lugar',
                          uploaded: widget.business.archivo360 != null,
                          isUploading: _uploadingAssets.contains('archivo360'),
                          onTap: () => _uploadAsset('archivo360'),
                        ),
                        const SizedBox(height: 10),
                        _AssetUploadRow(
                          icon: Icons.qr_code_2_outlined,
                          label: 'Modelo AR – Marcador',
                          hint: 'Archivo 3D (.glb/.gltf) para escaneo por QR o marcador físico',
                          uploaded: widget.business.arMarcador != null,
                          isUploading: _uploadingAssets.contains('arMarcador'),
                          onTap: () => _uploadAsset('arMarcador'),
                        ),
                        const SizedBox(height: 10),
                        _AssetUploadRow(
                          icon: Icons.explore_outlined,
                          label: 'Modelo AR – Geolocalización',
                          hint: 'Archivo 3D (.glb/.gltf) para exploración por GPS en exteriores',
                          uploaded: widget.business.arGeo != null,
                          isUploading: _uploadingAssets.contains('arGeo'),
                          onTap: () => _uploadAsset('arGeo'),
                        ),
                      ],
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: TextStyle(color: AppColors.errorRed, fontSize: 13)),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          variant: AppButtonVariant.ghost,
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Cancelar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AppButton(
                          backgroundColor: AppColors.businessOrange,
                          foregroundColor: Colors.white,
                          onPressed: _isSaving ? null : _save,
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
    );
  }
}

class _AssetUploadRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String hint;
  final bool uploaded;
  final bool isUploading;
  final VoidCallback onTap;

  const _AssetUploadRow({
    required this.icon,
    required this.label,
    required this.hint,
    required this.uploaded,
    required this.isUploading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.overlay(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.overlay(0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: uploaded ? AppColors.businessOrange.withOpacity(0.15) : AppColors.overlay(0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: uploaded ? AppColors.businessOrange.withOpacity(0.3) : AppColors.overlay(0.1)),
            ),
            child: Icon(uploaded ? Icons.check_circle : icon, size: 16, color: uploaded ? AppColors.businessOrange : AppColors.slate400),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(hint, style: TextStyle(color: AppColors.slate500, fontSize: 11, height: 1.3)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (isUploading)
            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
          else
            TextButton.icon(
              onPressed: onTap,
              icon: Icon(Icons.upload_outlined, size: 14, color: AppColors.businessOrange),
              label: Text(uploaded ? 'Reemplazar' : 'Subir', style: TextStyle(color: AppColors.businessOrange, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }
}
