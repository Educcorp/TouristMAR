import 'package:flutter/material.dart';

import '../models/business_profile.dart';
import '../services/auth_service.dart';
import '../services/session_storage.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/app_text_field.dart';

/// Formulario para que una cuenta de negocio ya aprobada sugiera un negocio
/// adicional — cae en la misma cola de "Solicitudes" del admin que un
/// registro nuevo. Al aprobarse, queda ligado a esta misma cuenta.
class BusinessSuggestPage extends StatefulWidget {
  const BusinessSuggestPage({super.key});

  @override
  State<BusinessSuggestPage> createState() => _BusinessSuggestPageState();
}

class _BusinessSuggestPageState extends State<BusinessSuggestPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _categoryController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final _authService = AuthService();
  bool _isSaving = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

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
      final updated = await _authService.createNegocioSuggestion(
        token,
        nombre: _nameController.text.trim(),
        categoria: _categoryController.text.trim(),
        descripcion: _descriptionController.text.trim(),
        direccion: _addressController.text.trim(),
      );
      final nuevo = updated.negocios.last;
      if (mounted) Navigator.of(context).pop(BusinessProfile.fromNegocioInfo(updated, nuevo));
    } catch (err) {
      setState(() => _error = err is AuthError ? err.message : 'No se pudo enviar la sugerencia');
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
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(Icons.arrow_back, size: 15, color: AppColors.slate400),
                        label: Text('Volver', style: TextStyle(color: AppColors.slate400, fontSize: 13)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('Sugerir negocio nuevo', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 24)),
                    const SizedBox(height: 4),
                    Text(
                      'Un administrador revisará esta solicitud. Si se aprueba, quedará ligada a tu cuenta para que la administres desde aquí.',
                      style: TextStyle(color: AppColors.slate400, fontSize: 14),
                    ),
                    const SizedBox(height: 24),
                    AppTextField(
                      label: 'Nombre del negocio',
                      icon: Icons.apartment,
                      controller: _nameController,
                      accentColor: AppColors.businessOrange,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa el nombre del negocio' : null,
                    ),
                    const SizedBox(height: 20),
                    AppTextField(
                      label: 'Categoría',
                      icon: Icons.local_offer_outlined,
                      controller: _categoryController,
                      hintText: 'Ej. Playa · Restaurante · Bar',
                      accentColor: AppColors.businessOrange,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa una categoría' : null,
                    ),
                    const SizedBox(height: 20),
                    AppTextField(
                      label: 'Dirección',
                      icon: Icons.place_outlined,
                      controller: _addressController,
                      hintText: 'Calle, número, colonia…',
                      accentColor: AppColors.businessOrange,
                    ),
                    const SizedBox(height: 20),
                    Text('Descripción', style: TextStyle(color: AppColors.slate300, fontSize: 14)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _descriptionController,
                      maxLength: 350,
                      maxLines: 4,
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Describe brevemente el lugar…',
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
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cancelar'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppButton(
                            backgroundColor: AppColors.businessOrange,
                            foregroundColor: Colors.white,
                            onPressed: _isSaving ? null : _submit,
                            child: Text(_isSaving ? 'Enviando...' : 'Enviar sugerencia'),
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
}
