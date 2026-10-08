import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'app_logo.dart';

/// Lo que la app hace, pintado con la franja de su esmalte. Son capacidades
/// reales del producto, no cifras: el panel no inventa conteos ni promedios.
const _franjas = [
  (AppColors.turquesa, Icons.qr_code_scanner, 'Realidad aumentada con marcadores'),
  (AppColors.azul, Icons.explore_outlined, 'Realidad aumentada al llegar al lugar'),
  (AppColors.rojo, Icons.threesixty, 'Recorridos 360°'),
  (AppColors.amarillo, Icons.storefront_outlined, 'Negocios locales verificados'),
];

/// Panel izquierdo del login en pantallas anchas: la foto de la bahía arriba
/// de la línea de flotación y, abajo, el casco en tinta marina con lo que se
/// puede hacer en la app.
class HeroPanel extends StatelessWidget {
  const HeroPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset('assets/images/hero-manzanillo.jpg', fit: BoxFit.cover, alignment: Alignment.centerLeft),
              Positioned(
                left: 32,
                top: 28,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(10, 8, 14, 8),
                  decoration: BoxDecoration(color: AppColors.riel, borderRadius: BorderRadius.circular(AppRadius.button)),
                  child: Row(
                    children: [
                      AppLogo(size: 30, sobreFoto: true),
                      const SizedBox(width: 8),
                      const Text(
                        'TOURISTMAR',
                        style: TextStyle(color: AppColors.sobreRiel, fontWeight: FontWeight.w700, letterSpacing: 2, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Row(children: [for (final f in _franjas) Expanded(child: Container(height: kFranja, color: f.$1))]),
        Container(
          color: AppColors.riel,
          padding: const EdgeInsets.fromLTRB(40, 32, 40, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Manzanillo, lugar por lugar',
                style: AppTypography.display.copyWith(color: AppColors.sobreRiel, fontSize: 44),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: const Text(
                  'Playas, mariscos, miradores y cultura del puerto. Encuentra qué hay cerca '
                  'y vive cada lugar con realidad aumentada o en 360°.',
                  style: TextStyle(color: AppColors.sobreRielSuave, fontSize: 17, height: 1.45),
                ),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 24,
                runSpacing: 14,
                children: [
                  for (final f in _franjas)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 18,
                          height: kFranja,
                          decoration: BoxDecoration(color: f.$1, borderRadius: BorderRadius.circular(2)),
                        ),
                        const SizedBox(width: 8),
                        Icon(f.$2, size: 18, color: AppColors.sobreRiel),
                        const SizedBox(width: 6),
                        Text(f.$3, style: const TextStyle(color: AppColors.sobreRiel, fontSize: 15, fontWeight: FontWeight.w500)),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
