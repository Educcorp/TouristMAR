import 'package:flutter/material.dart';

import '../../services/resenas_service.dart';
import '../../theme/app_theme.dart';
import '../user_avatar.dart';

/// Fila de 5 estrellas llenas hasta [valor] (solo lectura).
class EstrellasFila extends StatelessWidget {
  final int valor;
  final double size;

  const EstrellasFila({super.key, required this.valor, this.size = 14});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
        (i) => Icon(i < valor ? Icons.star : Icons.star_border, size: size, color: i < valor ? Colors.amber : AppColors.slate500),
      ),
    );
  }
}

/// Promedio, total y barras por cantidad de estrellas.
class ResumenResenasCard extends StatelessWidget {
  final ResumenResenas resumen;

  const ResumenResenasCard({super.key, required this.resumen});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                resumen.total == 0 ? '—' : resumen.promedio.toStringAsFixed(1),
                style: TextStyle(color: AppColors.textPrimary, fontSize: 36, fontWeight: FontWeight.w700),
              ),
              EstrellasFila(valor: resumen.promedio.round(), size: 14),
              const SizedBox(height: 4),
              Text(
                resumen.total == 1 ? '1 reseña' : '${resumen.total} reseñas',
                style: TextStyle(color: AppColors.slate400, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(width: AppSpacing.xl),
          Expanded(
            child: Column(
              children: List.generate(5, (i) {
                final estrellas = 5 - i;
                final pct = resumen.porcentaje(estrellas);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Text('$estrellas', style: TextStyle(color: AppColors.slate400, fontSize: 12)),
                      const SizedBox(width: 4),
                      const Icon(Icons.star, size: 10, color: Colors.amber),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: pct / 100,
                            minHeight: 6,
                            backgroundColor: AppColors.overlay(0.08),
                            valueColor: const AlwaysStoppedAnimation(Colors.amber),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 32,
                        child: Text('$pct%', textAlign: TextAlign.right, style: TextStyle(color: AppColors.slate400, fontSize: 12)),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

/// Una reseña: autor, fecha, estrellas, comentario y, si la hay, la respuesta
/// del negocio. [acciones] se muestra al final (editar/borrar, responder…).
class ResenaTile extends StatelessWidget {
  final Resena resena;
  final Widget? acciones;

  const ResenaTile({super.key, required this.resena, this.acciones});

  @override
  Widget build(BuildContext context) {
    final comentario = resena.comentario;
    final respuesta = resena.respuesta;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: resena.mia ? AppColors.brandTeal.withValues(alpha: 0.5) : AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UserAvatar(imageUrl: resena.autorAvatarUrl, fallbackLetter: resena.autorNombre, radius: 16),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      resena.mia ? '${resena.autorNombre} (tú)' : resena.autorNombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    Text(resena.fecha, style: TextStyle(color: AppColors.slate500, fontSize: 12)),
                  ],
                ),
              ),
              EstrellasFila(valor: resena.estrellas, size: 13),
            ],
          ),
          if (comentario != null && comentario.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(comentario, style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4)),
          ],
          if (respuesta != null && respuesta.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(AppRadius.button),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Respuesta del negocio',
                      style: TextStyle(color: AppColors.brandTeal, fontSize: 12, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(respuesta, style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4)),
                ],
              ),
            ),
          ],
          if (acciones != null) ...[const SizedBox(height: AppSpacing.sm), acciones!],
        ],
      ),
    );
  }
}

/// Las últimas [max] reseñas de un negocio, para el dashboard y "Mi negocio".
/// `resenas == null` mientras cargan.
class ResenasRecientes extends StatelessWidget {
  final List<Resena>? resenas;
  final int max;

  const ResenasRecientes({super.key, required this.resenas, this.max = 2});

  @override
  Widget build(BuildContext context) {
    final lista = resenas;
    if (lista == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }
    if (lista.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Text(
          'Aún no hay reseñas de visitantes.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.slate400, fontSize: 13),
        ),
      );
    }
    return Column(children: lista.take(max).map((r) => ResenaTile(resena: r)).toList());
  }
}
