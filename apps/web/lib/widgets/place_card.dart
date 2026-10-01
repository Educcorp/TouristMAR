import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class PlaceCard extends StatelessWidget {
  final String image;
  final String category;
  final String name;
  final double rating;
  final bool isFavorite;
  final VoidCallback? onTap;
  final VoidCallback? onToggleFavorite;

  const PlaceCard({
    super.key,
    required this.image,
    required this.category,
    required this.name,
    required this.rating,
    this.isFavorite = false,
    this.onTap,
    this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.panelNavySoft,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio: 16 / 11,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(image, fit: BoxFit.cover),
                  Positioned(
                    left: 10,
                    top: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.brandTeal.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        category,
                        style: TextStyle(color: AppColors.panelNavy, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 10,
                    top: 10,
                    child: GestureDetector(
                      onTap: onToggleFavorite,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.4), shape: BoxShape.circle),
                        child: Icon(
                          isFavorite ? Icons.favorite : Icons.favorite_border,
                          size: 16,
                          // Va sobre la foto (fondo negro translúcido), así que usa siempre el
                          // cian claro: en modo claro brandTeal es un azul oscuro que casi
                          // no se veía.
                          color: isFavorite ? const Color(0xFF22D3EE) : Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      ...List.generate(5, (_) => const Icon(Icons.star, size: 14, color: Colors.amber)),
                      const SizedBox(width: 6),
                      Text(
                        rating.toString(),
                        style: const TextStyle(color: Colors.amber, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
