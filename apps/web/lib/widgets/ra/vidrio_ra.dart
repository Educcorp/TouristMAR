import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Piezas del diseño "Liquid Glass" de las pantallas de realidad aumentada,
/// el mismo del equipo de RA en Unity (VisorLiquidGlass.cs para la RA por
/// geolocalización y VisorARResponsive.cs para los marcadores): vidrio oscuro
/// translúcido que desenfoca la cámara, filo que capta la luz arriba, chip de
/// estado con punto que late, categoría en mayúsculas y botón píldora.
abstract final class RaEstilo {
  /// Cian de la RA por geolocalización (colorAcento de ControladorPlayas).
  static const acento = Color(0xFF4FD8E0);

  /// Texto sobre el botón de acento (textoBotonActivo).
  static const textoSobreAcento = Color(0xFF042226);

  /// Ámbar: "aún no llegas".
  static const lejos = Color(0xFFFFC759);

  /// Tinte del vidrio (0.08, 0.09, 0.10, 0.70).
  static const tinte = Color(0xB3141719);
  static const cuerpo = Color(0xC7FFFFFF); // blanco al 78 %
  static const secundario = Color(0x99FFFFFF); // blanco al 60 %
}

/// Panel de vidrio: desenfoque de lo que hay detrás, tinte oscuro, reflejo
/// suave arriba a la izquierda y un filo de luz más brillante arriba.
class VidrioRa extends StatelessWidget {
  final Widget child;
  final double radio;
  final EdgeInsetsGeometry padding;
  final Color tinte;

  const VidrioRa({
    super.key,
    required this.child,
    this.radio = 32,
    this.padding = EdgeInsets.zero,
    this.tinte = RaEstilo.tinte,
  });

  @override
  Widget build(BuildContext context) {
    final borde = BorderRadius.circular(radio);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borde,
        boxShadow: const [BoxShadow(color: Color(0x52000000), blurRadius: 40, offset: Offset(0, 16))],
      ),
      child: ClipRRect(
        borderRadius: borde,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: CustomPaint(
            foregroundPainter: _BordeLuz(radio),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: tinte,
                gradient: const RadialGradient(
                  center: Alignment(-0.45, -0.85),
                  radius: 0.9,
                  colors: [Color(0x14FFFFFF), Color(0x00FFFFFF)],
                ),
              ),
              child: Material(
                type: MaterialType.transparency,
                child: Padding(padding: padding, child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Filo de ~1 px: brillante arriba (45 %) y casi apagado abajo (7 %).
class _BordeLuz extends CustomPainter {
  final double radio;

  _BordeLuz(this.radio);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final r = math.min(radio, size.shortestSide / 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(0.6), Radius.circular(r)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x73FFFFFF), Color(0x12FFFFFF)],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_BordeLuz old) => old.radio != radio;
}

/// Chip de estado: punto de color (que late si [latido]) y texto corto.
class ChipEstadoRa extends StatefulWidget {
  final String texto;
  final Color color;
  final bool latido;

  const ChipEstadoRa({super.key, required this.texto, required this.color, this.latido = false});

  @override
  State<ChipEstadoRa> createState() => _ChipEstadoRaState();
}

class _ChipEstadoRaState extends State<ChipEstadoRa> with SingleTickerProviderStateMixin {
  late final AnimationController _pulso = AnimationController(vsync: this, duration: const Duration(milliseconds: 1250));

  @override
  void initState() {
    super.initState();
    _sincronizar();
  }

  @override
  void didUpdateWidget(ChipEstadoRa oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.latido != widget.latido) _sincronizar();
  }

  void _sincronizar() {
    if (widget.latido) {
      _pulso.repeat();
    } else {
      _pulso
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _pulso.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      padding: const EdgeInsets.only(left: 13, right: 15),
      decoration: BoxDecoration(
        color: const Color(0x17FFFFFF),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0x29FFFFFF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: 9,
            child: AnimatedBuilder(
              animation: _pulso,
              builder: (context, _) {
                final t = _pulso.value;
                final halo = widget.latido ? 1 + 1.6 * t : 1.7;
                final alfa = widget.latido ? 0.45 * (1 - t) : 0.15;
                return Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Transform.scale(
                      scale: halo,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: widget.color.withValues(alpha: alfa),
                        ),
                        child: const SizedBox.square(dimension: 9),
                      ),
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color),
                      child: const SizedBox.square(dimension: 9),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(width: 9),
          Flexible(
            child: Text(
              widget.texto,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xE6FFFFFF),
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Categoría arriba del título: mayúsculas, color de acento, tracking amplio.
class CategoriaRa extends StatelessWidget {
  final String texto;
  final Color color;

  const CategoriaRa(this.texto, {super.key, this.color = RaEstilo.acento});

  @override
  Widget build(BuildContext context) {
    return Text(
      texto.trim().toUpperCase(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 1.7),
    );
  }
}

/// Título grande y compacto de la tarjeta.
class TituloRa extends StatelessWidget {
  final String texto;
  final int? maxLineas;
  final double tamano;

  const TituloRa(this.texto, {super.key, this.maxLineas, this.tamano = 26});

  @override
  Widget build(BuildContext context) {
    return Text(
      texto,
      maxLines: maxLineas,
      overflow: maxLineas == null ? null : TextOverflow.ellipsis,
      style: TextStyle(
        color: Colors.white,
        fontSize: tamano,
        height: 1.08,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
      ),
    );
  }
}

/// Botón píldora: [activo] = relleno de acento (acción disponible); si no,
/// vidrio atenuado. Sin [onTap] queda deshabilitado (p. ej. "Acércate para
/// ver más").
class BotonPildoraRa extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool activo;
  final Color acento;

  const BotonPildoraRa({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.activo = false,
    this.acento = RaEstilo.acento,
  });

  @override
  Widget build(BuildContext context) {
    final texto = activo ? RaEstilo.textoSobreAcento : (onTap == null ? const Color(0x8CFFFFFF) : Colors.white);
    final forma = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(28),
      side: BorderSide(color: activo ? const Color(0x59FFFFFF) : const Color(0x33FFFFFF)),
    );
    return Material(
      color: activo ? acento : const Color(0x12FFFFFF),
      shape: forma,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[Icon(icon, size: 18, color: texto), const SizedBox(width: 8)],
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: texto, fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 0.3),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Línea fina entre el contenido y los botones.
class DivisorRa extends StatelessWidget {
  const DivisorRa({super.key});

  @override
  Widget build(BuildContext context) => Container(height: 1, color: const Color(0x1AFFFFFF));
}

/// Botón redondo de vidrio (cerrar, volver).
class BotonCircularRa extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final double lado;

  const BotonCircularRa({super.key, required this.icon, required this.tooltip, required this.onTap, this.lado = 46});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: VidrioRa(
        radio: lado / 2,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox.square(dimension: lado, child: Icon(icon, color: Colors.white, size: 20)),
        ),
      ),
    );
  }
}
