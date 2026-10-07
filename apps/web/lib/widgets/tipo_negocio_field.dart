import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_text_field.dart';

/// Tipos de negocio que se eligen al registrarse. Se guardan tal cual en
/// `negocio_profiles.categoria`; "Otro" guarda lo que escriba el negocio.
const tiposNegocio = ['Club de playa', 'Club nocturno', 'Restaurante'];
const tipoNegocioOtro = 'Otro';

/// Lista desplegable del tipo de negocio (no texto libre). Con "Otro"
/// aparece un campo obligatorio para escribir de qué es el negocio.
/// Usa [valorTipoNegocio] para obtener lo que se manda al backend.
class TipoNegocioField extends StatelessWidget {
  final String? seleccionado;
  final ValueChanged<String?> onChanged;
  final TextEditingController otroController;
  final Color? accentColor;

  const TipoNegocioField({
    super.key,
    required this.seleccionado,
    required this.onChanged,
    required this.otroController,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder borde(Color color) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: color));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tipo de negocio', style: TextStyle(color: AppColors.slate300, fontSize: 14)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          key: const ValueKey('category-field'),
          initialValue: seleccionado,
          isExpanded: true,
          dropdownColor: AppColors.panelNavySoft,
          style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
          hint: Text('Selecciona el tipo', style: TextStyle(color: AppColors.slate500, fontSize: 14)),
          icon: Icon(Icons.keyboard_arrow_down, color: AppColors.slate400),
          decoration: InputDecoration(
            prefixIcon: Icon(Icons.local_offer_outlined, size: 18, color: AppColors.slate500),
            filled: true,
            fillColor: AppColors.panelNavySoft,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            border: borde(AppColors.overlay(0.1)),
            enabledBorder: borde(AppColors.overlay(0.1)),
            focusedBorder: borde(accentColor ?? AppColors.brandTeal),
            errorBorder: borde(AppColors.errorRed),
            focusedErrorBorder: borde(AppColors.errorRed),
          ),
          items: [
            for (final t in [...tiposNegocio, tipoNegocioOtro]) DropdownMenuItem(value: t, child: Text(t)),
          ],
          validator: (v) => v == null ? 'Selecciona el tipo de negocio' : null,
          onChanged: onChanged,
        ),
        if (seleccionado == tipoNegocioOtro) ...[
          const SizedBox(height: 12),
          AppTextField(
            fieldKey: const ValueKey('category-other-field'),
            label: '¿De qué es tu negocio?',
            icon: Icons.edit_outlined,
            controller: otroController,
            hintText: 'Ej. Tienda de artesanías, renta de kayaks…',
            accentColor: accentColor,
            validator: (v) {
              final t = v?.trim() ?? '';
              if (t.isEmpty) return 'Escribe de qué es tu negocio';
              if (t.length > 60) return 'Máximo 60 caracteres';
              return null;
            },
          ),
        ],
      ],
    );
  }
}

/// Lo que se guarda como categoría: el tipo elegido o, con "Otro", lo escrito.
String? valorTipoNegocio(String? seleccionado, TextEditingController otroController) {
  if (seleccionado == null) return null;
  return seleccionado == tipoNegocioOtro ? otroController.text.trim() : seleccionado;
}
