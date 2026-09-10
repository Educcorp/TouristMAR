import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/visitor_profile.dart';
import '../services/auth_service.dart';
import '../services/session_storage.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/user_avatar.dart';

class EditProfilePage extends StatefulWidget {
  final VisitorProfile profile;

  const EditProfilePage({super.key, required this.profile});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late final _nameController = TextEditingController(text: widget.profile.name);
  late final _bioController = TextEditingController(text: widget.profile.bio);
  final _authService = AuthService();
  bool _isSaving = false;
  bool _isUploadingPhoto = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _changePhoto() async {
    final token = SessionStorage.token;
    if (token == null) {
      setState(() => _error = 'Tu sesión expiró, vuelve a iniciar sesión');
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    final file = result?.files.single;
    if (file == null || file.bytes == null) return;

    setState(() {
      _isUploadingPhoto = true;
      _error = null;
    });

    try {
      final updated = await _authService.uploadAvatar(token, file.bytes!, file.name);
      setState(() => widget.profile.avatarUrl = updated.avatarUrl);
    } catch (err) {
      setState(() => _error = err is AuthError ? err.message : 'No se pudo subir la foto');
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
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
        'nombres': _nameController.text.trim(),
        'bio': _bioController.text.trim(),
      });
      widget.profile.name = updated.name;
      widget.profile.bio = updated.bio ?? '';
      if (mounted) Navigator.of(context).pop(true);
    } catch (err) {
      setState(() => _error = err is AuthError ? err.message : 'No se pudo guardar el perfil');
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
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => Navigator.of(context).pop(false),
                      icon: const Icon(Icons.arrow_back, size: 15, color: AppColors.slate400),
                      label: const Text('Volver a mi perfil', style: TextStyle(color: AppColors.slate400, fontSize: 13)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('Editar perfil', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 24)),
                  const SizedBox(height: 4),
                  const Text(
                    'Actualiza tu foto, nombre y descripción personal.',
                    style: TextStyle(color: AppColors.slate400, fontSize: 14),
                  ),
                  const SizedBox(height: 28),
                  Center(
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: _isUploadingPhoto ? null : _changePhoto,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              UserAvatar(
                                imageUrl: widget.profile.avatarUrl,
                                fallbackLetter: _nameController.text,
                                radius: 48,
                              ),
                              if (_isUploadingPhoto)
                                const CircularProgressIndicator(color: AppColors.brandTeal),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextButton.icon(
                          onPressed: _isUploadingPhoto ? null : _changePhoto,
                          icon: const Icon(Icons.camera_alt_outlined, size: 13, color: AppColors.brandTeal),
                          label: const Text('Cambiar foto', style: TextStyle(color: AppColors.brandTeal, fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Nombre completo', style: TextStyle(color: AppColors.slate300, fontSize: 14)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameController,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: _inputDecoration(),
                  ),
                  const SizedBox(height: 20),
                  const Text('Descripción personal', style: TextStyle(color: AppColors.slate300, fontSize: 14)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _bioController,
                    maxLength: 200,
                    maxLines: 4,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: _inputDecoration(hint: 'Cuéntanos un poco sobre ti…'),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: AppColors.errorRed, fontSize: 13)),
                  ],
                  const SizedBox(height: 12),
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

  InputDecoration _inputDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.slate500),
      filled: true,
      fillColor: AppColors.panelNavySoft,
      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      counterStyle: const TextStyle(color: AppColors.slate500, fontSize: 11),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.brandTeal),
      ),
    );
  }
}
