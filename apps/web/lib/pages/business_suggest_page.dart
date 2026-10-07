import 'package:flutter/material.dart';

import '../models/business_profile.dart';
import '../models/lugar.dart';
import '../services/auth_service.dart';
import '../services/image_picker_service.dart';
import '../services/session_storage.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/app_text_field.dart';
import '../widgets/mapa/selector_ubicacion.dart';
import '../widgets/themed_builder.dart';

/// Formulario para que una cuenta de negocio ya aprobada sugiera un negocio
/// adicional — cae en la misma cola de "Solicitudes" del admin que un
/// registro nuevo. Al aprobarse, queda ligado a esta misma cuenta.
///
/// Lleva lo que el admin necesita para revisarlo sin pedir nada más: imagen
/// de portada, nombre, categoría, ubicación en el mapa, dirección, teléfono,
/// horario y descripción. El admin recibe una notificación y puede corregir
/// cualquiera de esos datos antes de aprobar.
class BusinessSuggestPage extends StatefulWidget {
  final AuthService? authService;

  const BusinessSuggestPage({super.key, this.authService});

  @override
  State<BusinessSuggestPage> createState() => _BusinessSuggestPageState();
}

class _BusinessSuggestPageState extends State<BusinessSuggestPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _categoryController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _scheduleController = TextEditingController();
  late final AuthService _authService = widget.authService ?? AuthService();
  PickedImage? _portada;
  Coordenadas? _ubicacion;
  bool _isSaving = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _scheduleController.dispose();
    super.dispose();
  }

  Future<void> _pickPortada() async {
    final picked = await ImagePickerService.pick();
    if (picked == null || !mounted) return;
    setState(() => _portada = picked);
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
        telefono: _phoneController.text.trim(),
        horario: _scheduleController.text.trim(),
        latitud: _ubicacion?.lat,
        longitud: _ubicacion?.lng,
      );
      var user = updated;
      final nuevo = updated.negocios.last;
      String? aviso;
      // La portada se sube aparte (multipart) una vez que el negocio existe.
      // Si falla, la solicitud ya quedó enviada: se avisa y el admin o la
      // empresa pueden subirla después.
      final portada = _portada;
      if (portada != null) {
        try {
          user = await _authService.uploadNegocioPortada(token, nuevo.id, portada.bytes, portada.name);
        } catch (_) {
          aviso = 'La solicitud se envió, pero no se pudo subir la imagen. Podrás agregarla después.';
        }
      }
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      final negocio = user.negocios.firstWhere((n) => n.id == nuevo.id, orElse: () => nuevo);
      Navigator.of(context).pop(BusinessProfile.fromNegocioInfo(user, negocio));
      messenger?.showSnackBar(SnackBar(content: Text(aviso ?? 'Solicitud enviada. Te avisaremos cuando un administrador la revise.')));
    } catch (err) {
      if (!mounted) return;
      setState(() => _error = err is AuthError ? err.message : 'No se pudo enviar la sugerencia');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) => ThemedBuilder(builder: _buildScaffold);

  Widget _buildScaffold(BuildContext context) {
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
                    _PortadaPicker(
                      portada: _portada,
                      onPick: _isSaving ? null : _pickPortada,
                      onRemove: _isSaving ? null : () => setState(() => _portada = null),
                    ),
                    const SizedBox(height: 20),
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
                    UbicacionField(
                      value: _ubicacion,
                      accent: AppColors.businessOrange,
                      enabled: !_isSaving,
                      onChanged: (v) => setState(() => _ubicacion = v),
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
                    AppTextField(
                      label: 'Teléfono (opcional)',
                      icon: Icons.phone_outlined,
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      hintText: 'Ej. 314 123 4567',
                      accentColor: AppColors.businessOrange,
                    ),
                    const SizedBox(height: 20),
                    AppTextField(
                      label: 'Horario (opcional)',
                      icon: Icons.schedule_outlined,
                      controller: _scheduleController,
                      hintText: 'Ej. Lun–Dom 9:00–21:00',
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

/// Vista previa de la imagen de portada elegida (todavía sin subir).
class _PortadaPicker extends StatelessWidget {
  final PickedImage? portada;
  final VoidCallback? onPick;
  final VoidCallback? onRemove;

  const _PortadaPicker({required this.portada, required this.onPick, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final p = portada;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Imagen de portada', style: TextStyle(color: AppColors.slate300, fontSize: 14)),
        const SizedBox(height: 8),
        InkWell(
          onTap: onPick,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 150,
            width: double.infinity,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.panelNavySoft,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.overlay(0.1)),
              image: p == null ? null : DecorationImage(image: MemoryImage(p.bytes), fit: BoxFit.cover),
            ),
            child: p != null
                ? Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Material(
                        color: Colors.black54,
                        shape: const CircleBorder(),
                        child: IconButton(
                          tooltip: 'Quitar imagen',
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.close, size: 16, color: Colors.white),
                          onPressed: onRemove,
                        ),
                      ),
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_photo_alternate_outlined, size: 30, color: AppColors.businessOrange),
                      const SizedBox(height: 6),
                      Text('Elegir imagen', style: TextStyle(color: AppColors.slate300, fontSize: 13)),
                      const SizedBox(height: 2),
                      Text('PNG, JPG o WEBP · máx. 5 MB', style: TextStyle(color: AppColors.slate500, fontSize: 11)),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
