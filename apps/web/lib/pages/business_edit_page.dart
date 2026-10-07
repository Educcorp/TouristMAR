import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/business_profile.dart';
import '../models/lugar.dart';
import '../services/auth_service.dart';
import '../services/image_picker_service.dart';
import '../services/recorridos_service.dart';
import '../services/session_storage.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/app_text_field.dart';
import '../widgets/business/solicitud_recorrido_card.dart';
import '../widgets/cover_image.dart';
import '../widgets/mapa/ubicacion_lugar.dart';
import '../widgets/themed_builder.dart';

class BusinessEditPage extends StatefulWidget {
  final BusinessProfile business;

  /// Solo para pruebas: permite usar servicios con un cliente HTTP falso.
  final AuthService? authService;
  final RecorridosService? recorridosService;

  const BusinessEditPage({super.key, required this.business, this.authService, this.recorridosService});

  @override
  State<BusinessEditPage> createState() => _BusinessEditPageState();
}

class _BusinessEditPageState extends State<BusinessEditPage> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(text: widget.business.businessName);
  late final _categoryController = TextEditingController(text: widget.business.category);
  late final _descriptionController = TextEditingController(text: widget.business.description);
  late final _addressController = TextEditingController(text: widget.business.address);
  /// Pin del negocio en el mapa (va junto a la dirección).
  late Coordenadas? _ubicacion = widget.business.latitud != null && widget.business.longitud != null
      ? Coordenadas(widget.business.latitud!, widget.business.longitud!)
      : null;
  late final _phoneController = TextEditingController(text: widget.business.phone);
  late final _websiteController = TextEditingController(text: widget.business.website);
  late final _hoursController = TextEditingController(text: widget.business.hours);
  late final AuthService _authService = widget.authService ?? AuthService();
  late final RecorridosService _recorridosService = widget.recorridosService ?? RecorridosService();
  bool _isSaving = false;
  String? _error;

  /// Si ya tiene recorrido 360° o una solicitud en curso (null = cargando).
  /// Si no se pudo consultar, el bloque del recorrido no se muestra.
  EstadoRecorridoNegocio? _recorrido;
  bool _recorridoNoDisponible = false;

  /// El pin que ya está guardado en el servidor (el de [_ubicacion] puede ser
  /// uno nuevo sin guardar).
  bool get _pinGuardado =>
      _ubicacion != null && widget.business.latitud == _ubicacion!.lat && widget.business.longitud == _ubicacion!.lng;

  /// Portada elegida pero aún no guardada (Error 5.3). Antes se subía al
  /// elegirla y quedaba aplicada aunque se tocara "Cancelar"; ahora se sube
  /// junto con el resto de los cambios en [_save].
  Uint8List? _pendingCoverBytes;
  String? _pendingCoverName;

  static final _websitePattern = RegExp(r'^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}(/.*)?$');

  String? _requiredValidator(String? v, String message) {
    return (v == null || v.trim().isEmpty) ? message : null;
  }

  String? _phoneValidator(String? v) {
    if (v == null || v.trim().isEmpty) return 'Ingresa un teléfono';
    final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 7) return 'Ingresa un teléfono válido';
    return null;
  }

  String? _websiteValidator(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    if (!_websitePattern.hasMatch(v.trim())) return 'Ingresa un sitio web válido';
    return null;
  }

  /// Solo elige la portada y la muestra como vista previa; no la sube.
  Future<void> _changeCover() async {
    final picked = await ImagePickerService.pick();
    if (picked == null || !mounted) return;

    setState(() {
      _pendingCoverBytes = picked.bytes;
      _pendingCoverName = picked.name;
      _error = null;
    });
  }

  @override
  void initState() {
    super.initState();
    _cargarRecorrido();
  }

  Future<void> _cargarRecorrido() async {
    final token = SessionStorage.token;
    if (token == null) {
      setState(() => _recorridoNoDisponible = true);
      return;
    }
    try {
      final estado = await _recorridosService.estadoNegocio(token, widget.business.id);
      if (mounted) setState(() => _recorrido = estado);
    } catch (_) {
      if (mounted) setState(() => _recorridoNoDisponible = true);
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

  /// Guarda el formulario y, con [solicitarRecorrido], después envía la
  /// solicitud de recorrido 360° (el backend la pide con el pin ya guardado).
  Future<void> _save({bool solicitarRecorrido = false}) async {
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
      // La portada nueva (si hay) se sube hasta ahora, al guardar.
      String? newCover;
      if (_pendingCoverBytes != null) {
        final withCover = await _authService.uploadNegocioPortada(
          token,
          widget.business.id,
          _pendingCoverBytes!,
          _pendingCoverName ?? 'portada.jpg',
        );
        final m = withCover.negocios.where((n) => n.id == widget.business.id);
        newCover = m.isEmpty ? null : m.first.portada;
      }

      final updated = await _authService.updateNegocio(token, widget.business.id, {
        'nombre': _nameController.text.trim(),
        'categoria': _categoryController.text.trim(),
        'descripcion': _descriptionController.text.trim(),
        'direccion': _addressController.text.trim(),
        'telefono': _phoneController.text.trim(),
        'sitioWeb': _websiteController.text.trim(),
        'horario': _hoursController.text.trim(),
        'latitud': _ubicacion?.lat,
        'longitud': _ubicacion?.lng,
      });

      final business = widget.business;
      final matches = updated.negocios.where((n) => n.id == widget.business.id);
      final negocio = matches.isEmpty ? null : matches.first;
      business.businessName = negocio?.nombre ?? _nameController.text.trim();
      business.category = negocio?.categoria ?? '';
      business.description = negocio?.descripcion ?? '';
      business.address = negocio?.direccion ?? '';
      business.phone = negocio?.telefono ?? '';
      business.website = negocio?.sitioWeb ?? '';
      business.hours = negocio?.horario ?? '';
      business.latitud = negocio?.latitud;
      business.longitud = negocio?.longitud;
      final portada = negocio?.portada ?? newCover;
      if (portada != null) business.coverImage = portada;

      if (solicitarRecorrido) {
        try {
          final solicitud = await _recorridosService.solicitar(token, business.id);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cambios guardados y solicitud de recorrido 360° enviada')),
          );
          setState(() => _recorrido = EstadoRecorridoNegocio(tieneRecorrido: false, solicitud: solicitud));
        } catch (err) {
          // Los datos sí se guardaron: se queda en la página para que vea el
          // motivo y pueda reintentar solo la solicitud.
          if (mounted) {
            setState(() => _error = 'Se guardaron los cambios, pero no se pudo enviar la solicitud: '
                '${err is AuthError ? err.message : 'sin conexión con el servidor'}');
          }
          return;
        }
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (err) {
      setState(() => _error = err is AuthError ? err.message : 'No se pudo guardar el negocio');
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
              constraints: const BoxConstraints(maxWidth: 520),
              child: Form(
                key: _formKey,
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
                      onTap: _isSaving ? null : _changeCover,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: SizedBox(
                          height: 140,
                          width: double.infinity,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              _pendingCoverBytes != null
                                  ? Image.memory(_pendingCoverBytes!, fit: BoxFit.cover)
                                  : CoverImage(source: widget.business.coverImage),
                              DecoratedBox(decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.25))),
                              Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 22),
                                    const SizedBox(height: 6),
                                    Text(
                                      _pendingCoverBytes != null
                                          ? 'Vista previa — se aplicará al guardar'
                                          : 'Cambiar foto de portada',
                                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                    ),
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
                      validator: (v) => _requiredValidator(v, 'Ingresa el nombre del negocio'),
                    ),
                    const SizedBox(height: 20),
                    AppTextField(
                      label: 'Categoría',
                      icon: Icons.local_offer_outlined,
                      controller: _categoryController,
                      hintText: 'Ej. Playa · Restaurante · Bar',
                      accentColor: AppColors.businessOrange,
                      validator: (v) => _requiredValidator(v, 'Ingresa una categoría'),
                    ),
                    const SizedBox(height: 20),
                    Text('Descripción', style: TextStyle(color: AppColors.slate300, fontSize: 14)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _descriptionController,
                      maxLength: 350,
                      maxLines: 4,
                      onChanged: (_) => setState(() {}),
                      validator: (v) => _requiredValidator(v, 'Describe brevemente tu negocio'),
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
                        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.errorRed)),
                        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.errorRed)),
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
                            validator: (v) => _requiredValidator(v, 'Ingresa la dirección'),
                          ),
                          const SizedBox(height: 16),
                          CampoCoordenadas(
                            lugar: _nameController.text.trim().isEmpty ? 'tu negocio' : _nameController.text.trim(),
                            inicial: _ubicacion,
                            acento: AppColors.businessOrange,
                            habilitado: !_isSaving,
                            marcarEnMapa: true,
                            onChanged: (c) => setState(() => _ubicacion = c),
                          ),
                          if (!_recorridoNoDisponible) ...[
                            const SizedBox(height: 16),
                            SolicitudRecorridoCard(
                              estado: _recorrido,
                              tienePin: _ubicacion != null,
                              pinGuardado: _pinGuardado,
                              ocupado: _isSaving,
                              onSolicitar: () => _save(solicitarRecorrido: true),
                            ),
                          ],
                          const SizedBox(height: 16),
                          AppTextField(
                            label: 'Teléfono',
                            icon: Icons.phone_outlined,
                            controller: _phoneController,
                            hintText: '+52 314 000 0000',
                            keyboardType: TextInputType.phone,
                            accentColor: AppColors.businessOrange,
                            validator: _phoneValidator,
                          ),
                          const SizedBox(height: 16),
                          AppTextField(
                            label: 'Sitio web',
                            icon: Icons.language,
                            controller: _websiteController,
                            hintText: 'miweb.com.mx',
                            keyboardType: TextInputType.url,
                            accentColor: AppColors.businessOrange,
                            validator: _websiteValidator,
                          ),
                          const SizedBox(height: 16),
                          AppTextField(
                            label: 'Horario',
                            icon: Icons.schedule_outlined,
                            controller: _hoursController,
                            hintText: 'Lun – Dom: 9:00 am – 6:00 pm',
                            accentColor: AppColors.businessOrange,
                            validator: (v) => _requiredValidator(v, 'Ingresa el horario'),
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
      ),
    );
  }
}
