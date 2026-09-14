import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'ds_card.dart';
import 'ds_icon_badge.dart';

/// Tarjeta de estadística del dashboard/reportes. El "sparkline" es
/// puramente decorativo (una curva derivada del valor, no una serie
/// histórica real) porque el backend no expone datos de tendencia — no se
/// simula un "+X% vs. mes anterior" que no se pueda respaldar con datos.
class DsStatCard extends StatelessWidget {
  final IconData icon;
  final int value;
  final String label;
  final Color accent;

  const DsStatCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return DsCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              DsIconBadgeCircle(icon: icon, color: accent, size: 36),
              SizedBox(
                width: 64,
                height: 24,
                child: CustomPaint(painter: _SparklinePainter(seed: value, color: accent)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: value.toDouble()),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (context, animated, _) => Text(
              '${animated.round()}',
              style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: AppTypography.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final int seed;
  final Color color;

  _SparklinePainter({required this.seed, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(seed);
    final points = List.generate(7, (i) => 0.25 + rnd.nextDouble() * 0.6);

    final path = Path();
    final dx = size.width / (points.length - 1);
    for (var i = 0; i < points.length; i++) {
      final x = i * dx;
      final y = size.height * (1 - points[i]);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final paint = Paint()
      ..color = color.withOpacity(0.55)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) =>
      oldDelegate.seed != seed || oldDelegate.color != color;
}
