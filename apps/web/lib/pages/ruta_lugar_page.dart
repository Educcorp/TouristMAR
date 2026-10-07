import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../models/lugar.dart';
import '../services/experiencias_launcher.dart';
import '../services/ruta_service.dart';
import '../services/ubicacion_dispositivo.dart';
import '../theme/app_theme.dart';
import '../widgets/experiencias/experiencias_lugar.dart' show ExperienciaSituacion;
import '../widgets/mapa/mapa_lugares.dart';
import '../widgets/themed_builder.dart';

/// "Cómo llegar" dentro de nuestro mapa (antes mandaba a Google Maps): tu
/// posición en vivo, la ruta a pie hasta [lugar] y, si el lugar tiene RA por
/// ubicación, su zona; al entrar a la zona se habilita "Abrir RA".
Future<void> abrirRutaEnMapa(BuildContext context, Lugar lugar) {
  return Navigator.of(context).push(MaterialPageRoute(builder: (_) => RutaLugarPage(lugar: lugar)));
}

class RutaLugarPage extends StatefulWidget {
  final Lugar lugar;

  /// Solo para pruebas.
  final RutaService? rutaService;
  final Stream<Coordenadas>? ubicaciones;

  const RutaLugarPage({super.key, required this.lugar, this.rutaService, this.ubicaciones});

  @override
  State<RutaLugarPage> createState() => _RutaLugarPageState();
}

class _RutaLugarPageState extends State<RutaLugarPage> {
  final _mapa = MapController();
  late final RutaService _rutas = widget.rutaService ?? RutaService();
  StreamSubscription<Coordenadas>? _sub;

  Coordenadas? _yo;
  RutaCalculada? _ruta;
  /// Desde dónde se calculó [_ruta]: si el visitante se aleja de ahí, se recalcula.
  Coordenadas? _origenRuta;
  bool _calculando = false;
  bool _buscandoUbicacion = true;
  bool _encuadrado = false;

  Coordenadas get _destino => widget.lugar.ubicacion!;

  @override
  void initState() {
    super.initState();
    _seguir();
  }

  void _seguir() {
    _sub?.cancel();
    setState(() => _buscandoUbicacion = true);
    _sub = (widget.ubicaciones ?? UbicacionDispositivo.seguir()).listen(
      _alMoverse,
      onDone: () {
        if (mounted) setState(() => _buscandoUbicacion = false);
      },
      onError: (_) {
        if (mounted) setState(() => _buscandoUbicacion = false);
      },
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    _mapa.dispose();
    super.dispose();
  }

  void _alMoverse(Coordenadas yo) {
    if (!mounted) return;
    setState(() {
      _yo = yo;
      _buscandoUbicacion = false;
    });
    final origen = _origenRuta;
    // Solo se pide otra ruta si se alejó bastante (el servidor es público).
    if (origen == null || distanciaMetros(origen, yo) > 150) _calcularRuta(yo);
    if (!_encuadrado) {
      _encuadrado = true;
      _encuadrar();
    }
  }

  Future<void> _calcularRuta(Coordenadas yo) async {
    if (_calculando) return;
    setState(() => _calculando = true);
    _origenRuta = yo;
    final ruta = await _rutas.aPie(yo, _destino);
    if (!mounted) return;
    setState(() {
      _ruta = ruta;
      _calculando = false;
    });
    _encuadrar();
  }

  /// Muestra la ruta completa (o tú y el lugar si aún no hay ruta).
  void _encuadrar() {
    final puntos = [
      ...?_ruta?.puntos,
      if (_yo != null) _yo!,
      _destino,
    ].map(toLatLng).toList();
    try {
      if (puntos.length < 2) {
        _mapa.move(toLatLng(_destino), 16);
      } else {
        _mapa.fitCamera(CameraFit.coordinates(
          coordinates: puntos,
          padding: const EdgeInsets.fromLTRB(48, 96, 48, 260),
          maxZoom: 17,
        ));
      }
    } catch (_) {
      // El mapa todavía no se dibuja; se encuadra en el siguiente cambio.
      _encuadrado = false;
    }
  }

  bool get _tieneGeo =>
      ExperienciaSituacion.calcular(widget.lugar, ExperienciaTipo.arGeo, _yo).estado != ExperienciaEstado.noDisponible;

  /// Con tu distancia real (en el teléfono, Unity además vuelve a medirla).
  bool get _enZona => _yo != null && distanciaMetros(_yo!, _destino) <= widget.lugar.radioDesbloqueo;

  /// Unity mide la distancia por su cuenta y deja abrir siempre; en lo demás
  /// solo dentro de la zona.
  bool get _puedeAbrirRa => _enZona || ExperienciasLauncher.current.mideDistancia(ExperienciaTipo.arGeo);

  Future<void> _abrirRa() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ExperienciasLauncher.current.abrir(context, widget.lugar, ExperienciaTipo.arGeo);
    } on ExperienciaError catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.mensaje)));
    } on ExperienciaNoConfigurada {
      messenger.showSnackBar(
        const SnackBar(content: Text('La RA por geolocalización necesita la cámara de tu teléfono.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => ThemedBuilder(builder: _build);

  Widget _build(BuildContext context) {
    final color = ExperienciaInfo.of(ExperienciaTipo.arGeo).color;
    final lineaRecta = _ruta == null && _yo != null;
    return Scaffold(
      backgroundColor: AppColors.panelNavy,
      body: Stack(
        children: [
          Positioned.fill(
            child: MapaBase(
              controller: _mapa,
              centro: _destino,
              zoom: 15,
              children: [
                if (_tieneGeo) capaRadio(_destino, widget.lugar.radioDesbloqueo, color),
                if (_ruta != null || lineaRecta)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: (_ruta?.puntos ?? [_yo!, _destino]).map(toLatLng).toList(),
                        strokeWidth: 5,
                        color: AppColors.brandTeal,
                        borderStrokeWidth: 2,
                        borderColor: Colors.white.withValues(alpha: 0.8),
                        // Sin ruta por calles: solo la dirección, punteada.
                        pattern: lineaRecta ? StrokePattern.dashed(segments: const [10, 8]) : const StrokePattern.solid(),
                      ),
                    ],
                  ),
                capaLugares([widget.lugar], seleccionadoId: widget.lugar.id),
                if (_yo != null)
                  MarkerLayer(markers: [
                    Marker(point: toLatLng(_yo!), width: 22, height: 22, child: const _PuntoYo()),
                  ]),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  _BotonRedondo(
                    icon: Icons.arrow_back,
                    tooltip: 'Volver',
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: _decoracionFlotante(),
                      child: Text(
                        'Cómo llegar a ${widget.lugar.nombre}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 12,
            bottom: 230,
            child: Column(
              children: [
                ControlesMapa(controller: _mapa, centro: _destino, zoomInicial: 15),
                const SizedBox(height: 8),
                _BotonRedondo(
                  icon: Icons.my_location,
                  tooltip: 'Ver toda la ruta',
                  onTap: _encuadrar,
                ),
              ],
            ),
          ),
          Positioned(left: 12, right: 12, bottom: 12, child: SafeArea(top: false, child: _panel(color))),
        ],
      ),
    );
  }

  Widget _panel(Color colorGeo) {
    final yo = _yo;
    final distancia = _ruta?.metros ?? (yo == null ? null : distanciaMetros(yo, _destino));

    final String resumen;
    if (yo == null) {
      resumen = _buscandoUbicacion ? 'Buscando tu ubicación…' : 'Activa tu ubicación para ver la ruta.';
    } else if (_ruta != null) {
      resumen = '${formatoDistancia(_ruta!.metros)} a pie · ${_minutos(_ruta!.segundos)}';
    } else if (_calculando) {
      resumen = 'Calculando ruta…';
    } else {
      resumen = '${formatoDistancia(distancia!)} en línea recta (no se pudo calcular la ruta por calles)';
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: _decoracionFlotante(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.lugar.nombre,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.directions_walk, size: 16, color: AppColors.brandTeal),
              const SizedBox(width: 6),
              Expanded(child: Text(resumen, style: AppTypography.bodySmall)),
            ],
          ),
          if (yo == null && !_buscandoUbicacion) ...[
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: _seguir,
              icon: const Icon(Icons.location_searching, size: 16),
              label: const Text('Usar mi ubicación'),
            ),
          ],
          if (_tieneGeo) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Icon(Icons.radar, size: 16, color: colorGeo),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _enZona
                        ? 'Estás en la zona de realidad aumentada.'
                        : yo == null
                            ? 'Realidad aumentada en un radio de ${widget.lugar.radioDesbloqueo.round()} m del lugar.'
                            : 'Te faltan ${formatoDistancia(distanciaMetros(yo, _destino) - widget.lugar.radioDesbloqueo)} '
                                'para la zona de realidad aumentada.',
                    style: TextStyle(color: colorGeo, fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            FilledButton.icon(
              onPressed: _puedeAbrirRa ? _abrirRa : null,
              icon: const Icon(Icons.view_in_ar, size: 18),
              label: const Text('Abrir realidad aumentada', style: TextStyle(fontWeight: FontWeight.w700)),
              style: FilledButton.styleFrom(
                backgroundColor: colorGeo,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _minutos(double segundos) {
    final min = (segundos / 60).round();
    if (min < 60) return '${min < 1 ? 1 : min} min';
    return '${min ~/ 60} h ${min % 60} min';
  }
}

BoxDecoration _decoracionFlotante() => BoxDecoration(
      color: AppColors.panelNavySoft,
      borderRadius: BorderRadius.circular(AppRadius.card),
      border: Border.all(color: AppColors.borderSubtle),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 18, offset: const Offset(0, 6))],
    );

class _BotonRedondo extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _BotonRedondo({required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.panelNavySoft,
        shape: CircleBorder(side: BorderSide(color: AppColors.borderSubtle)),
        elevation: 2,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(width: 42, height: 42, child: Icon(icon, size: 20, color: AppColors.textPrimary)),
        ),
      ),
    );
  }
}

/// Punto azul de "estás aquí".
class _PuntoYo extends StatelessWidget {
  const _PuntoYo();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2563EB),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [BoxShadow(color: const Color(0xFF2563EB).withValues(alpha: 0.4), blurRadius: 10, spreadRadius: 4)],
      ),
    );
  }
}
