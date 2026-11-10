import 'package:flutter/material.dart';

import '../services/categorias_service.dart';
import '../theme/app_theme.dart';
import 'app_text_field.dart';

/// "Otro" guarda lo que escriba el negocio en vez de una categoría de la lista.
const tipoNegocioOtro = 'Otro';

/// Valor inicial del desplegable para una categoría ya guardada: ella misma
/// si está en la lista, "Otro" si es texto libre (y entonces el texto va en el
/// campo de "Otro"), null si está vacía.
String? tipoNegocioInicial(String categoria, List<String> opciones) {
  final c = categoria.trim();
  if (c.isEmpty) return null;
  for (final o in opciones) {
    if (o.toLowerCase() == c.toLowerCase()) return o;
  }
  return tipoNegocioOtro;
}

/// Lista desplegable de la categoría del negocio (no texto libre). Las
/// opciones son las que administra el panel admin (`GET /api/categorias`).
/// Con "Otro" aparece un campo obligatorio para escribir de qué es el negocio.
/// Usa [valorTipoNegocio] para obtener lo que se manda al backend.
class TipoNegocioField extends StatefulWidget {
  final String? seleccionado;
  final ValueChanged<String?> onChanged;
  final TextEditingController otroController;
  final Color? accentColor;
  final String etiqueta;
  final CategoriasService? service;

  const TipoNegocioField({
    super.key,
    required this.seleccionado,
    required this.onChanged,
    required this.otroController,
    this.accentColor,
    this.etiqueta = 'Tipo de negocio',
    this.service,
  });

  @override
  State<TipoNegocioField> createState() => _TipoNegocioFieldState();
}

class _TipoNegocioFieldState extends State<TipoNegocioField> {
  List<String> _opciones = CategoriasService.respaldo;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final opciones = await (widget.service ?? CategoriasService()).nombres();
    if (!mounted) return;
    setState(() => _opciones = opciones);
    // Una categoría escrita como "Otro" que ahora sí está en la lista.
    if (widget.seleccionado == tipoNegocioOtro) {
      final enLista = tipoNegocioInicial(widget.otroController.text, opciones);
      if (enLista != null && enLista != tipoNegocioOtro) widget.onChanged(enLista);
    } else if (widget.seleccionado != null && !opciones.contains(widget.seleccionado)) {
      widget.otroController.text = widget.seleccionado!;
      widget.onChanged(tipoNegocioOtro);
    }
  }

  @override
  Widget build(BuildContext context) {
    final seleccionado = widget.seleccionado;
    final onChanged = widget.onChanged;
    final otroController = widget.otroController;
    final accentColor = widget.accentColor;
    OutlineInputBorder borde(Color color) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: color));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.etiqueta, style: TextStyle(color: AppColors.slate300, fontSize: 14)),
        const SizedBox(height: 8),
        KeyedSubtree(
          // El desplegable toma su valor solo al crearse: se recrea si cambian
          // las opciones o la selección desde fuera.
          key: ValueKey('${_opciones.length}-$seleccionado'),
          child: DropdownButtonFormField<String>(
            key: const ValueKey('category-field'),
            initialValue: seleccionado == null || seleccionado == tipoNegocioOtro || _opciones.contains(seleccionado)
                ? seleccionado
                : tipoNegocioOtro,
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
              for (final t in [..._opciones, tipoNegocioOtro]) DropdownMenuItem(value: t, child: Text(t)),
            ],
            validator: (v) => v == null ? 'Selecciona el tipo de negocio' : null,
            onChanged: onChanged,
          ),
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
