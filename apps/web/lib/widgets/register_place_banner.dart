import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class RegisterPlaceBanner extends StatelessWidget {
  final VoidCallback? onTap;

  const RegisterPlaceBanner({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.overlay(0.05),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap ?? () {},
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.overlay(0.1)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: AppColors.brandTeal.withValues(alpha: 0.15), shape: BoxShape.circle),
                child: Icon(Icons.location_on_outlined, size: 18, color: AppColors.brandTeal),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '¿Te gustaría registrar un lugar nuevo?',
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    Text(
                      'Propón tu negocio o sitio turístico',
                      style: TextStyle(color: AppColors.slate400, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: AppColors.slate400),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ventana flotante (con el fondo borroso) que explica cómo se da de alta un
/// lugar: cuenta de empresa → solicitud → revisión del admin → mapa.
/// Devuelve `true` si el usuario quiere ir al registro de empresa.
Future<bool> mostrarGuiaRegistrarLugar(BuildContext context, {bool cierraSesion = false}) async {
  final ir = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Cerrar',
    barrierColor: Colors.black.withValues(alpha: 0.35),
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (dialogContext, _, __) => _GuiaRegistrarLugar(cierraSesion: cierraSesion),
    transitionBuilder: (_, anim, __, child) => BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 8 * anim.value, sigmaY: 8 * anim.value),
      child: FadeTransition(
        opacity: anim,
        child: ScaleTransition(scale: Tween(begin: 0.96, end: 1.0).animate(anim), child: child),
      ),
    ),
  );
  return ir == true;
}

class _GuiaRegistrarLugar extends StatelessWidget {
  final bool cierraSesion;

  const _GuiaRegistrarLugar({required this.cierraSesion});

  static const _pasos = [
    (Icons.storefront_outlined, 'Crea tu cuenta de empresa', 'Con tu correo y una contraseña. Es gratis.'),
    (Icons.edit_note, 'Describe tu negocio', 'Nombre, tipo, ubicación y fotos de portada.'),
    (Icons.verified_outlined, 'Un administrador lo revisa', 'Te avisamos por notificación cuando quede aprobado.'),
    (Icons.map_outlined, 'Aparece en el mapa', 'Ya aprobado, puedes pedir recorrido 360° y realidad aumentada.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Material(
            color: AppColors.panelNavySoft,
            borderRadius: BorderRadius.circular(AppRadius.card),
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text('Registrar un lugar nuevo', style: AppTypography.h2)),
                      IconButton(
                        tooltip: 'Cerrar',
                        onPressed: () => Navigator.of(context).pop(false),
                        icon: Icon(Icons.close, color: AppColors.slate400),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Los lugares los dan de alta las cuentas de empresa. Así funciona:',
                    style: AppTypography.body,
                  ),
                  const SizedBox(height: 20),
                  for (var i = 0; i < _pasos.length; i++)
                    _Paso(numero: i + 1, icono: _pasos[i].$1, titulo: _pasos[i].$2, detalle: _pasos[i].$3, ultimo: i == _pasos.length - 1),
                  if (cierraSesion) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Al continuar se cerrará tu sesión de visitante.',
                      style: AppTypography.bodySmall.copyWith(color: AppColors.slate400),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context).pop(true),
                    icon: const Icon(Icons.arrow_forward, size: 18),
                    label: const Text('Ir al registro de empresa', style: TextStyle(fontWeight: FontWeight.w700)),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.tinta,
                      foregroundColor: AppColors.casco,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Paso extends StatelessWidget {
  final int numero;
  final IconData icono;
  final String titulo;
  final String detalle;
  final bool ultimo;

  const _Paso({required this.numero, required this.icono, required this.titulo, required this.detalle, required this.ultimo});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: AppColors.brandTeal.withValues(alpha: 0.15), shape: BoxShape.circle),
                child: Text('$numero', style: TextStyle(color: AppColors.brandTeal, fontWeight: FontWeight.w700)),
              ),
              if (!ultimo) Expanded(child: Container(width: 2, color: AppColors.borderSubtle)),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 4, bottom: ultimo ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icono, size: 18, color: AppColors.tinta),
                      const SizedBox(width: 6),
                      Flexible(child: Text(titulo, style: AppTypography.h3.copyWith(fontSize: 15))),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(detalle, style: AppTypography.bodySmall.copyWith(color: AppColors.slate300)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
