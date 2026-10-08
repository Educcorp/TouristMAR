import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/lugar.dart';
import '../../theme/app_theme.dart';

/// El "escenario" donde se va a montar cada experiencia: la vista de Unity
/// (RA) o el visor 3D/360°. Mientras no exista, dibuja un fondo de
/// referencia (rejilla en perspectiva para RA, meridianos para 360°) con un
/// mensaje. Cuando el visor real esté listo, se pasa en [child] y ocupa el
/// mismo espacio con las mismas esquinas y controles.
class ExperienciaViewport extends StatelessWidget {
  final ExperienciaTipo tipo;
  final Widget? child;
  final String? mensaje;
  final double aspectRatio;
  final bool bloqueado;

  /// Controles superpuestos en la esquina inferior derecha (pantalla
  /// completa, reiniciar vista, etc.).
  final List<Widget> controles;

  const ExperienciaViewport({
    super.key,
    required this.tipo,
    this.child,
    this.mensaje,
    this.aspectRatio = 16 / 9,
    this.bloqueado = false,
    this.controles = const [],
  });

  @override
  Widget build(BuildContext context) {
    final info = ExperienciaInfo.of(tipo);
    final color = info.color;

    return AspectRatio(
      aspectRatio: aspectRatio,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Siempre oscuro, sin importar el tema: es una "pantalla".
            const ColoredBox(color: AppColors.scrimDark),
            CustomPaint(
              painter: tipo == ExperienciaTipo.recorrido360 ? _EsferaPainter(color) : _RejillaPainter(color),
            ),
            if (child != null)
              child!
            else
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(color: color.withValues(alpha: 0.5)),
                        ),
                        child: Icon(bloqueado ? Icons.lock_outline : info.icon, color: color, size: 26),
                      ),
                      if (mensaje != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          mensaje!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            // Esquinas tipo visor de cámara.
            Padding(
              padding: const EdgeInsets.all(10),
              child: CustomPaint(painter: _EsquinasPainter(Colors.white.withValues(alpha: 0.35))),
            ),
            Positioned(
              left: 12,
              top: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(info.icon, size: 11, color: color),
                    const SizedBox(width: 4),
                    Text(
                      info.tituloCorto.toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1),
                    ),
                  ],
                ),
              ),
            ),
            if (controles.isNotEmpty)
              Positioned(
                right: 12,
                bottom: 12,
                child: Row(mainAxisSize: MainAxisSize.min, children: controles),
              ),
          ],
        ),
      ),
    );
  }
}

/// Botón redondo translúcido para [ExperienciaViewport.controles].
class ViewportControl extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  const ViewportControl({super.key, required this.icon, required this.tooltip, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.black.withValues(alpha: 0.45),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(icon, size: 16, color: onPressed == null ? Colors.white38 : Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

class _RejillaPainter extends CustomPainter {
  final Color color;
  _RejillaPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.18)
      ..strokeWidth = 1;
    final horizonte = size.height * 0.45;
    final centro = size.width / 2;

    // Líneas que fugan al horizonte.
    for (var i = -8; i <= 8; i++) {
      final x = centro + i * size.width / 6;
      canvas.drawLine(Offset(centro + i * 6, horizonte), Offset(x, size.height), paint);
    }
    // Líneas horizontales cada vez más juntas hacia el horizonte.
    for (var i = 1; i <= 10; i++) {
      final t = math.pow(i / 10, 2).toDouble();
      final y = horizonte + (size.height - horizonte) * t;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_RejillaPainter old) => old.color != color;
}

class _EsferaPainter extends CustomPainter {
  final Color color;
  _EsferaPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final centro = Offset(size.width / 2, size.height / 2);
    final radio = size.shortestSide * 0.42;

    canvas.drawCircle(centro, radio, paint);
    // Meridianos.
    for (var i = 1; i <= 3; i++) {
      final w = radio * 2 * i / 4;
      canvas.drawOval(Rect.fromCenter(center: centro, width: w, height: radio * 2), paint);
    }
    // Paralelos.
    for (var i = -2; i <= 2; i++) {
      final y = centro.dy + i * radio / 3;
      final half = math.sqrt(math.max(0, radio * radio - math.pow(y - centro.dy, 2)));
      canvas.drawLine(Offset(centro.dx - half, y), Offset(centro.dx + half, y), paint);
    }
  }

  @override
  bool shouldRepaint(_EsferaPainter old) => old.color != color;
}

class _EsquinasPainter extends CustomPainter {
  final Color color;
  _EsquinasPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    const l = 16.0;
    final p = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final w = size.width;
    final h = size.height;
    canvas.drawPath(Path()..moveTo(0, l)..lineTo(0, 0)..lineTo(l, 0), p);
    canvas.drawPath(Path()..moveTo(w - l, 0)..lineTo(w, 0)..lineTo(w, l), p);
    canvas.drawPath(Path()..moveTo(0, h - l)..lineTo(0, h)..lineTo(l, h), p);
    canvas.drawPath(Path()..moveTo(w - l, h)..lineTo(w, h)..lineTo(w, h - l), p);
  }

  @override
  bool shouldRepaint(_EsquinasPainter old) => old.color != color;
}
