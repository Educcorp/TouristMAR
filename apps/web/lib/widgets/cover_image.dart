import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Muestra una foto de portada que puede ser un asset local (mock/default)
/// o una URL real subida a Supabase Storage. Sin foto (`source` vacío) pinta
/// el casco vacío: nunca una foto de otro lugar haciéndose pasar por esta.
class CoverImage extends StatelessWidget {
  final String source;
  final BoxFit fit;

  const CoverImage({super.key, required this.source, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    if (source.isEmpty) return const _SinFoto();
    if (source.startsWith('http')) {
      return Image.network(
        source,
        fit: fit,
        loadingBuilder: (context, child, progreso) =>
            progreso == null ? child : ColoredBox(color: AppColors.surfaceAlt),
        errorBuilder: (_, __, ___) => const _SinFoto(),
      );
    }
    return Image.asset(source, fit: fit, errorBuilder: (_, __, ___) => const _SinFoto());
  }
}

class _SinFoto extends StatelessWidget {
  const _SinFoto();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.surfaceAlt,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.photo_camera_outlined, size: 32, color: AppColors.slate400),
            const SizedBox(height: 6),
            Text('Sin foto todavía', style: AppTypography.caption.copyWith(color: AppColors.slate400)),
          ],
        ),
      ),
    );
  }
}
