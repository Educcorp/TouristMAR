import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../models/lugar.dart';
import '../../theme/app_theme.dart';
import '../../utils/keyboard.dart';
import '../themed_builder.dart';
import 'mapa_lugares.dart';

/// Abre un mapa a pantalla completa para marcar dónde está un negocio.
/// Devuelve el punto elegido, o `null` si el usuario sale sin confirmar.
///
/// Lo usan la empresa (al sugerir un negocio) y el admin (al revisar la
/// solicitud), así que la ubicación se elige igual en web y en el celular.
Future<Coordenadas?> elegirUbicacionEnMapa(
  BuildContext context, {
  Coordenadas? inicial,
  required Color accent,
}) {
  hideKeyboard();
  return Navigator.of(context).push<Coordenadas>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _SelectorUbicacionPage(inicial: inicial, accent: accent),
    ),
  );
}

String formatearCoordenadas(Coordenadas c) => '${c.lat.toStringAsFixed(5)}, ${c.lng.toStringAsFixed(5)}';

class _SelectorUbicacionPage extends StatefulWidget {
  final Coordenadas? inicial;
  final Color accent;

  const _SelectorUbicacionPage({this.inicial, required this.accent});

  @override
  State<_SelectorUbicacionPage> createState() => _SelectorUbicacionPageState();
}

class _SelectorUbicacionPageState extends State<_SelectorUbicacionPage> {
  late Coordenadas? _punto = widget.inicial;

  @override
  Widget build(BuildContext context) => ThemedBuilder(builder: _buildScaffold);

  Widget _buildScaffold(BuildContext context) {
    final punto = _punto;
    return Scaffold(
      backgroundColor: AppColors.panelNavy,
      appBar: AppBar(
        backgroundColor: AppColors.panelNavy,
        foregroundColor: AppColors.textPrimary,
        title: const Text('Ubicación del negocio', style: TextStyle(fontSize: 16)),
        actions: [
          TextButton(
            onPressed: punto == null ? null : () => Navigator.of(context).pop(punto),
            child: Text(
              'Listo',
              style: TextStyle(color: punto == null ? AppColors.slate500 : widget.accent, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          MapaBase(
            centro: widget.inicial ?? centroManzanillo,
            zoom: widget.inicial != null ? 16 : 13,
            onTap: (p) => setState(() => _punto = p),
            children: [
              if (punto != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: toLatLng(punto),
                      width: 44,
                      height: 44,
                      alignment: Alignment.topCenter,
                      child: Icon(Icons.location_on, color: widget.accent, size: 44),
                    ),
                  ],
                ),
            ],
          ),
          Positioned(
            left: 12,
            right: 12,
            top: 12,
            child: SafeArea(
              child: Material(
                color: AppColors.panelNavySoft,
                borderRadius: BorderRadius.circular(10),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      Icon(Icons.touch_app_outlined, size: 18, color: widget.accent),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          punto == null
                              ? 'Toca el mapa en el punto exacto del negocio.'
                              : 'Marcado en ${formatearCoordenadas(punto)}. Toca otro punto para moverlo.',
                          style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Campo de formulario "Ubicación en el mapa": muestra el punto elegido y un
/// botón para abrir [elegirUbicacionEnMapa]. No dibuja el mapa en línea (se
/// abre aparte), así el formulario sigue siendo ligero en el celular.
class UbicacionField extends StatelessWidget {
  final Coordenadas? value;
  final ValueChanged<Coordenadas?> onChanged;
  final Color accent;
  final bool enabled;

  // ignore: prefer_const_constructors_in_immutables
  UbicacionField({
    super.key,
    required this.value,
    required this.onChanged,
    required this.accent,
    this.enabled = true,
  });

  Future<void> _elegir(BuildContext context) async {
    final punto = await elegirUbicacionEnMapa(context, inicial: value, accent: accent);
    if (punto != null) onChanged(punto);
  }

  @override
  Widget build(BuildContext context) {
    final v = value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ubicación en el mapa', style: TextStyle(color: AppColors.slate300, fontSize: 14)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.panelNavySoft,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.overlay(0.1)),
          ),
          child: Row(
            children: [
              Icon(v == null ? Icons.location_off_outlined : Icons.location_on, size: 18, color: v == null ? AppColors.slate500 : accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  v == null ? 'Sin ubicación marcada' : formatearCoordenadas(v),
                  key: const Key('ubicacion-texto'),
                  style: TextStyle(color: v == null ? AppColors.slate500 : AppColors.textPrimary, fontSize: 13),
                ),
              ),
              if (v != null && enabled)
                IconButton(
                  tooltip: 'Quitar ubicación',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.close, size: 16, color: AppColors.slate400),
                  onPressed: () => onChanged(null),
                ),
              TextButton.icon(
                onPressed: enabled ? () => _elegir(context) : null,
                icon: Icon(Icons.map_outlined, size: 16, color: accent),
                label: Text(v == null ? 'Elegir en el mapa' : 'Cambiar', style: TextStyle(color: accent, fontSize: 13)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
