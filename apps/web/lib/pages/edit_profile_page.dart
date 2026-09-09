import 'package:flutter/material.dart';

import '../models/visitor_profile.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';

class EditProfilePage extends StatefulWidget {
  final VisitorProfile profile;

  const EditProfilePage({super.key, required this.profile});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late final _nameController = TextEditingController(text: widget.profile.name);
  late final _bioController = TextEditingController(text: widget.profile.bio);
  int _avatarSeed = 0;

  static const _avatarColors = [
    AppColors.brandTeal,
    AppColors.orange,
    AppColors.amber,
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _save() {
    widget.profile.name = _nameController.text.trim();
    widget.profile.bio = _bioController.text.trim();
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final avatarColor = _avatarColors[_avatarSeed % _avatarColors.length];

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
                          onTap: () => setState(() => _avatarSeed++),
                          child: CircleAvatar(
                            radius: 48,
                            backgroundColor: avatarColor.withOpacity(0.2),
                            child: Text(
                              _nameController.text.isNotEmpty ? _nameController.text[0].toUpperCase() : '?',
                              style: TextStyle(color: avatarColor, fontWeight: FontWeight.w700, fontSize: 34),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextButton.icon(
                          onPressed: () => setState(() => _avatarSeed++),
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
                        child: AppButton(onPressed: _save, child: const Text('Guardar cambios')),
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
