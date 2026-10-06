import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../models/lugar.dart';
import '../../theme/app_theme.dart';
import '../admin/ds_button.dart';
import 'mapa_lugares.dart';

/// Lee "19.12492145230218, -104.40020700589847" tal como se copia de Google
/// Maps (o los dos números separados por espacio). null si no son
/// coordenadas válidas.
Coordenadas? parsearCoordenadas(String texto) {
  final numeros = RegExp(r'-?\d+(?:\.\d+)?').allMatches(texto.replaceAll(',', ' , ')).map((m) => double.parse(m[0]!)).toList();
  if (numeros.length != 2) return null;
  final (lat, lng) = (numeros[0], numeros[1]);
  if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;
  return Coordenadas(lat, lng);
}

String _formato(Coordenadas c) => '${c.lat}, ${c.lng}';

/// Mapa en una ventana para elegir el pin tocando la entrada del lugar.
Future<Coordenadas?> elegirUbicacionEnMapa(BuildContext context, {required String lugar, Coordenadas? inicial, Color? acento}) {
  return showDialog<Coordenadas>(
    context: context,
    builder: (_) => _DialogoMapa(lugar: lugar, inicial: inicial, acento: acento ?? AppColors.adminViolet),
  );
}

/// Campo de coordenadas del lugar: se pegan desde Google Maps o se eligen en
/// el mapa, con una vista previa del pin. Es lo que pone el lugar en el mapa
/// público (y desde ahí, el turista entra a sus experiencias).
class CampoCoordenadas extends StatefulWidget {
  final String lugar;
  final Coordenadas? inicial;
  final ValueChanged<Coordenadas?> onChanged;
  final bool habilitado;

  /// Color del panel donde se usa (violeta en admin, naranja en empresa).
  final Color? acento;

  const CampoCoordenadas({
    super.key,
    required this.lugar,
    this.inicial,
    required this.onChanged,
    this.habilitado = true,
    this.acento,
  });

  @override
  State<CampoCoordenadas> createState() => _CampoCoordenadasState();
}

class _CampoCoordenadasState extends State<CampoCoordenadas> {
  late final _texto = TextEditingController(text: widget.inicial == null ? '' : _formato(widget.inicial!));
  late Coordenadas? _valor = widget.inicial;
  String? _error;
  final _mapa = MapController();

  @override
  void dispose() {
    _texto.dispose();
    _mapa.dispose();
    super.dispose();
  }

  void _cambiar(Coordenadas? c, {bool desdeTexto = false}) {
    setState(() {
      _valor = c;
      _error = null;
      if (!desdeTexto) _texto.text = c == null ? '' : _formato(c);
    });
    if (c != null) {
      try {
        _mapa.move(toLatLng(c), 16);
      } catch (_) {
        // El mapa todavía no estaba dibujado: se centra solo al aparecer.
      }
    }
    widget.onChanged(c);
  }

  void _alEscribir(String texto) {
    if (texto.trim().isEmpty) {
      _cambiar(null, desdeTexto: true);
      return;
    }
    final c = parsearCoordenadas(texto);
    if (c == null) {
      setState(() => _error = 'Escribe latitud, longitud (ej. 19.1006, -104.3399)');
      widget.onChanged(_valor);
      return;
    }
    _cambiar(c, desdeTexto: true);
  }

  Color get _acento => widget.acento ?? AppColors.adminViolet;

  Future<void> _elegir() async {
    final c = await elegirUbicacionEnMapa(context, lugar: widget.lugar, inicial: _valor, acento: _acento);
    if (c != null) _cambiar(c);
  }

  @override
  Widget build(BuildContext context) {
    final borde = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: AppColors.overlay(0.1)),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Coordenadas del lugar (pin en el mapa)', style: TextStyle(color: AppColors.slate300, fontSize: 14)),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _texto,
                enabled: widget.habilitado,
                onChanged: _alEscribir,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\- ]'))],
                style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.my_location, size: 18, color: AppColors.slate500),
                  hintText: 'Ej. 19.1006, -104.3399',
                  hintStyle: TextStyle(color: AppColors.slate500, fontSize: 13),
                  errorText: _error,
                  filled: true,
                  fillColor: AppColors.panelNavySoft,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  enabledBorder: borde,
                  border: borde,
                  focusedBorder: borde.copyWith(borderSide: BorderSide(color: _acento)),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: DsButton(
                label: 'Elegir en el mapa',
                icon: Icons.pin_drop_outlined,
                variant: DsButtonVariant.secondary,
                accent: _acento,
                onPressed: widget.habilitado ? _elegir : null,
              ),
            ),
          ],
        ),
        if (_valor != null) ...[
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.button),
            child: SizedBox(
              height: 170,
              child: MapaBase(
                key: ValueKey('${_valor!.lat},${_valor!.lng}'),
                controller: _mapa,
                centro: _valor!,
                zoom: 16,
                interactivo: false,
                children: [_capaPin(_valor!, _acento)],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

MarkerLayer _capaPin(Coordenadas c, Color color) => MarkerLayer(
      markers: [
        Marker(
          point: toLatLng(c),
          width: 40,
          height: 40,
          alignment: Alignment.topCenter,
          child: Icon(Icons.location_on, size: 40, color: color),
        ),
      ],
    );

class _DialogoMapa extends StatefulWidget {
  final String lugar;
  final Coordenadas? inicial;
  final Color acento;

  const _DialogoMapa({required this.lugar, this.inicial, required this.acento});

  @override
  State<_DialogoMapa> createState() => _DialogoMapaState();
}

class _DialogoMapaState extends State<_DialogoMapa> {
  late Coordenadas? _punto = widget.inicial;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.panelNavySoft,
      insetPadding: const EdgeInsets.all(AppSpacing.lg),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Ubicación de ${widget.lugar}', style: AppTypography.h3),
              const SizedBox(height: 4),
              Text(
                _punto == null ? '' : '$_punto',
                style: AppTypography.bodySmall,
              ),
              const SizedBox(height: AppSpacing.md),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.button),
                child: SizedBox(
                  height: 380,
                  child: MapaBase(
                    centro: widget.inicial ?? centroManzanillo,
                    zoom: widget.inicial == null ? 12.5 : 16,
                    onTap: (p) => setState(() => _punto = p),
                    children: [if (_punto != null) _capaPin(_punto!, widget.acento)],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: AppSpacing.sm,
                children: [
                  DsButton(label: 'Cancelar', variant: DsButtonVariant.ghost, onPressed: () => Navigator.of(context).pop()),
                  DsButton(
                    label: 'Usar este punto',
                    icon: Icons.check,
                    variant: DsButtonVariant.primary,
                    accent: widget.acento,
                    onPressed: _punto == null ? null : () => Navigator.of(context).pop(_punto),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
