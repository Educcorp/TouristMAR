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
/// de la línea de flotación y, abajo, lo que se puede hacer en la app. La
/// parte de abajo sigue el tema (blanca en modo claro, tinta en modo oscuro)
/// para que combine con el formulario de la derecha.
class HeroPanel extends StatelessWidget {
  // Sin `const` a propósito: build() lee AppColors (depende del tema); una
  // instancia const no se reconstruiría al cambiar entre claro y oscuro.
  // ignore: prefer_const_constructors_in_immutables
  HeroPanel({super.key});

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
                  // La etiqueta del logo también sigue el tema: blanca en modo
                  // claro y tinta marina en modo oscuro.
                  decoration: BoxDecoration(color: AppColors.cubierta, borderRadius: BorderRadius.circular(AppRadius.button)),
                  child: Row(
                    children: [
                      AppLogo(size: 30),
                      const SizedBox(width: 8),
                      Text(
                        'TOURISTMAR',
                        style: TextStyle(color: AppColors.tinta, fontWeight: FontWeight.w700, letterSpacing: 2, fontSize: 14),
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
          color: AppColors.cubierta,
          padding: const EdgeInsets.fromLTRB(40, 32, 40, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Manzanillo, lugar por lugar',
                style: AppTypography.display.copyWith(color: AppColors.tinta, fontSize: 44),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Text(
                  'Playas, mariscos, miradores y cultura del puerto. Encuentra qué hay cerca '
                  'y vive cada lugar con realidad aumentada o en 360°.',
                  style: TextStyle(color: AppColors.slate400, fontSize: 17, height: 1.45),
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
                        Icon(f.$2, size: 18, color: AppColors.tinta),
                        const SizedBox(width: 6),
                        Text(f.$3, style: TextStyle(color: AppColors.tinta, fontSize: 15, fontWeight: FontWeight.w500)),
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
