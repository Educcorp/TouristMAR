import 'package:flutter/material.dart';

import '../models/business_profile.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/app_text_field.dart';

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
  int _coverSeed = 0;

  static const _covers = [
    'assets/images/place-playa-audiencia.jpg',
    'assets/images/place-cerro-vigia.jpg',
    'assets/images/place-laguna-cuyutlan.jpg',
  ];

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

  void _save() {
    final business = widget.business;
    business.businessName = _nameController.text.trim();
    business.category = _categoryController.text.trim();
    business.description = _descriptionController.text.trim();
    business.address = _addressController.text.trim();
    business.phone = _phoneController.text.trim();
    business.website = _websiteController.text.trim();
    business.hours = _hoursController.text.trim();
    if (_coverSeed > 0) {
      business.coverImage = _covers[_coverSeed % _covers.length];
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final coverImage = _coverSeed == 0 ? widget.business.coverImage : _covers[_coverSeed % _covers.length];

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
                      icon: const Icon(Icons.arrow_back, size: 15, color: AppColors.slate400),
                      label: const Text('Volver a mi negocio', style: TextStyle(color: AppColors.slate400, fontSize: 13)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('Editar negocio', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 24)),
                  const SizedBox(height: 4),
                  const Text(
                    'Actualiza la información visible a los visitantes en el mapa.',
                    style: TextStyle(color: AppColors.slate400, fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  GestureDetector(
                    onTap: () => setState(() => _coverSeed++),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: SizedBox(
                        height: 140,
                        width: double.infinity,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.asset(coverImage, fit: BoxFit.cover),
                            DecoratedBox(decoration: BoxDecoration(color: Colors.black.withOpacity(0.25))),
                            const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.camera_alt_outlined, color: Colors.white, size: 22),
                                  SizedBox(height: 6),
                                  Text('Cambiar foto de portada', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
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
                  const Text('Descripción', style: TextStyle(color: AppColors.slate300, fontSize: 14)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _descriptionController,
                    maxLength: 350,
                    maxLines: 4,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Describe tu negocio o lugar turístico…',
                      hintStyle: const TextStyle(color: AppColors.slate500),
                      filled: true,
                      fillColor: AppColors.panelNavySoft,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                      counterStyle: const TextStyle(color: AppColors.slate500, fontSize: 11),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.businessOrange)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(20),
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08)))),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
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
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline, size: 15, color: AppColors.businessOrange),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Las fotos 360° y la tarjeta AR son generadas por el administrador de TourisMAR tras su visita al lugar.',
                            style: TextStyle(color: AppColors.slate400, fontSize: 12, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
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
                          onPressed: _save,
                          child: const Text('Guardar cambios'),
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
