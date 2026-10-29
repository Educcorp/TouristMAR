import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/visitor_profile.dart';
import '../services/auth_service.dart';
import '../services/image_picker_service.dart';
import '../services/session_storage.dart';
import '../theme/app_theme.dart';
import '../widgets/pagina_formulario.dart';
import '../widgets/app_button.dart';
import '../widgets/themed_builder.dart';
import '../widgets/user_avatar.dart';

class EditProfilePage extends StatefulWidget {
  final VisitorProfile profile;

  /// Solo para pruebas: permite usar un servicio con un cliente HTTP falso.
  final AuthService? authService;

  const EditProfilePage({super.key, required this.profile, this.authService});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late final _nameController = TextEditingController(text: widget.profile.name);
  late final _bioController = TextEditingController(text: widget.profile.bio);
  late final AuthService _authService = widget.authService ?? AuthService();
  bool _isSaving = false;
  String? _error;

  /// Foto elegida pero todavía NO guardada. Antes la foto se subía al
  /// servidor en cuanto se elegía y se escribía directo en
  /// `widget.profile.avatarUrl`, así que "Cancelar" no la deshacía: volvía a
  /// aparecer al reabrir "Editar perfil", al cambiar de tema o al reiniciar la
  /// app (Errores 4, 5 y 5.2). Ahora solo se sube al tocar "Guardar cambios";
  /// si se cancela, esta variable se descarta junto con la pantalla.
  Uint8List? _pendingPhotoBytes;
  String? _pendingPhotoName;

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  /// Solo elige la foto y la muestra como vista previa; no la sube.
  Future<void> _changePhoto() async {
    final picked = await ImagePickerService.pick();
    if (picked == null || !mounted) return;

    setState(() {
      _pendingPhotoBytes = picked.bytes;
      _pendingPhotoName = picked.name;
      _error = null;
    });
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
      // 1) La foto (si se eligió una) se sube hasta ahora, al guardar.
      String? newAvatarUrl;
      if (_pendingPhotoBytes != null) {
        final withPhoto =
            await _authService.uploadAvatar(token, _pendingPhotoBytes!, _pendingPhotoName ?? 'avatar.jpg');
        newAvatarUrl = withPhoto.avatarUrl;
      }

      // 2) Nombre y descripción.
      final updated = await _authService.updateProfile(token, {
        'nombres': _nameController.text.trim(),
        'bio': _bioController.text.trim(),
      });

      // 3) Solo con todo guardado se toca el perfil compartido.
      widget.profile.name = updated.name;
      widget.profile.bio = updated.bio ?? '';
      widget.profile.avatarUrl = updated.avatarUrl ?? newAvatarUrl ?? widget.profile.avatarUrl;
      if (mounted) Navigator.of(context).pop(true);
    } catch (err) {
      setState(() => _error = err is AuthError ? err.message : 'No se pudo guardar el perfil');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) => ThemedBuilder(builder: _buildScaffold);

  Widget _buildScaffold(BuildContext context) {
    return PaginaFormulario(
      volver: 'Volver a mi perfil',
      onVolver: () => Navigator.of(context).pop(false),
      titulo: 'Editar perfil',
      descripcion: 'Actualiza tu foto, nombre y descripción personal.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Column(
              children: [
                GestureDetector(
                  onTap: _isSaving ? null : _changePhoto,
                  child: _pendingPhotoBytes != null
                      ? CircleAvatar(
                          radius: 48,
                          backgroundColor: AppColors.surfaceAlt,
                          backgroundImage: MemoryImage(_pendingPhotoBytes!),
                        )
                      : UserAvatar(
                          imageUrl: widget.profile.avatarUrl,
                          fallbackLetter: _nameController.text,
                          radius: 48,
                        ),
                ),
                if (_pendingPhotoBytes != null) ...[
                  const SizedBox(height: 6),
                  Text('Vista previa: se aplicará al guardar', style: AppTypography.caption),
                ],
                const SizedBox(height: 6),
                TextButton.icon(
                  onPressed: _isSaving ? null : _changePhoto,
                  icon: const Icon(Icons.photo_camera_outlined, size: 18),
                  label: const Text('Cambiar foto'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Nombre completo', style: AppTypography.label),
          const SizedBox(height: 6),
          TextField(
            controller: _nameController,
            onChanged: (_) => setState(() {}),
            style: TextStyle(color: AppColors.textPrimary, fontSize: 16),
            decoration: _inputDecoration(),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Descripción personal', style: AppTypography.label),
          const SizedBox(height: 6),
          TextField(
            controller: _bioController,
            maxLength: 200,
            maxLines: 4,
            onChanged: (_) => setState(() {}),
            style: TextStyle(color: AppColors.textPrimary, fontSize: 16),
            decoration: _inputDecoration(hint: 'Cuéntanos un poco sobre ti…'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: AppColors.errorRed, fontSize: 14)),
          ],
          const SizedBox(height: AppSpacing.lg),
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
                  child: Text(_isSaving ? 'Guardando…' : 'Guardar cambios'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: AppColors.slate500, fontSize: 16),
      filled: true,
      fillColor: AppColors.panelNavySoft,
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
      counterStyle: AppTypography.caption,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.button),
        borderSide: BorderSide(color: AppColors.borderSubtle),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.button),
        borderSide: BorderSide(color: AppColors.borderSubtle),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.button),
        borderSide: BorderSide(color: AppColors.tinta, width: 2),
      ),
    );
  }
}
