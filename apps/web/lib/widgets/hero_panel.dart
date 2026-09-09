import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class _Category {
  final String label;
  final IconData icon;
  const _Category(this.label, this.icon);
}

class _Stat {
  final String value;
  final String label;
  const _Stat(this.value, this.label);
}

const _categories = [
  _Category('Playas', Icons.beach_access),
  _Category('Senderismo', Icons.hiking),
  _Category('Restaurantes', Icons.restaurant),
  _Category('Miradores', Icons.landscape),
  _Category('Recreación', Icons.attractions),
];

const _stats = [
  _Stat('80+', 'Lugares'),
  _Stat('4.8★', 'Valoración media'),
  _Stat('360°', 'Fotos inmersivas'),
];

class HeroPanel extends StatelessWidget {
  const HeroPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/images/hero-manzanillo.jpg',
          fit: BoxFit.cover,
          alignment: Alignment.centerLeft,
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                AppColors.panelNavy,
                AppColors.panelNavy.withOpacity(0.5),
                Colors.black.withOpacity(0.1),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(color: AppColors.brandTeal, shape: BoxShape.circle),
                    child: const Icon(Icons.waves, size: 20, color: AppColors.panelNavy),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'TOURISMAR',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, letterSpacing: 3, fontSize: 14),
                  ),
                ],
              ),
              const Spacer(),
              const Text(
                'MANZANILLO · COLIMA',
                style: TextStyle(color: AppColors.brandTeal, fontWeight: FontWeight.w600, fontSize: 12, letterSpacing: 3),
              ),
              const SizedBox(height: 16),
              Text('Descubre el Pacífico\nMexicano', style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: const Text(
                  'Playas, senderos de hiking, miradores y sabores locales — todo '
                  'centralizado para que explores Manzanillo como nunca antes.',
                  style: TextStyle(color: AppColors.slate300, fontSize: 15, height: 1.4),
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _categories.map((c) => _CategoryPill(category: c)).toList(),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.only(top: 20),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
                ),
                child: Row(
                  children: _stats
                      .map(
                        (s) => Padding(
                          padding: const EdgeInsets.only(right: 40),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s.value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600)),
                              Text(s.label, style: const TextStyle(color: AppColors.slate400, fontSize: 12)),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CategoryPill extends StatelessWidget {
  final _Category category;
  const _CategoryPill({required this.category});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(category.icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(category.label, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }
}
