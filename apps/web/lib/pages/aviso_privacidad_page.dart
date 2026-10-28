import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';
import '../widgets/themed_builder.dart';

/// Aviso de privacidad y uso de cookies (`/privacidad`). Es público: se abre
/// desde el login, el registro y el aviso de cookies sin iniciar sesión.
class AvisoPrivacidadPage extends StatelessWidget {
  const AvisoPrivacidadPage({super.key});

  /// Lo abre encima de la pantalla actual (funciona con o sin sesión).
  static Future<void> abrir(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const AvisoPrivacidadPage()));

  static const actualizado = '28 de octubre de 2026';

  static const _secciones = <(String, String)>[
    (
      'Quiénes somos',
      'TouristMAR es una guía turística de Manzanillo, Colima, con mapa de lugares, reseñas, realidad aumentada '
          'y recorridos 360°. Somos responsables del tratamiento de los datos personales que nos compartes al usar '
          'la aplicación web y móvil, conforme a la Ley Federal de Protección de Datos Personales en Posesión de los '
          'Particulares.',
    ),
    (
      'Qué datos recabamos',
      '• Cuenta: nombre, correo electrónico y contraseña (guardada cifrada, nunca en texto plano). Si entras con '
          'Google, recibimos tu nombre, correo y foto de perfil.\n'
          '• Perfil: foto, descripción y las reseñas, calificaciones y favoritos que publiques.\n'
          '• Negocios: nombre, categoría, descripción, dirección, ubicación en el mapa, teléfono, sitio web, horario, '
          'precios, menú y fotos del negocio.\n'
          '• Ubicación: solo cuando tú la compartes (para ordenar lugares por cercanía, trazar rutas o activar la '
          'realidad aumentada por ubicación). No la guardamos en nuestros servidores.\n'
          '• Uso: cuántas veces se abre la ficha de un lugar y cuántas veces se escanea un marcador de realidad '
          'aumentada, para mostrar estadísticas a los negocios y administradores.',
    ),
    (
      'Para qué los usamos',
      'Para crear y mantener tu cuenta, mostrar tus reseñas y favoritos, publicar la ficha de los negocios '
          'aprobados, enviarte notificaciones dentro de la app (por ejemplo, cuando un negocio responde tu reseña), '
          'moderar el contenido y generar estadísticas agregadas. No vendemos ni rentamos tus datos y no los usamos '
          'para publicidad.',
    ),
    (
      'Con quién los compartimos',
      'Tu nombre (con la inicial del apellido) y tus reseñas son visibles para otros usuarios. Los datos de un '
          'negocio aprobado son públicos en el mapa. Usamos proveedores para operar el servicio: alojamiento del '
          'servidor y la base de datos, almacenamiento de imágenes e inicio de sesión con Google. Solo reciben lo '
          'necesario para prestar su servicio.',
    ),
    (
      'Cookies y almacenamiento local',
      'No usamos cookies de publicidad ni de rastreo. El navegador guarda localmente tu sesión (para no pedirte la '
          'contraseña cada vez) y preferencias como el modo oscuro o haber cerrado este aviso. Puedes borrarlos en '
          'cualquier momento desde la configuración de tu navegador; al hacerlo se cerrará tu sesión. Los mosaicos '
          'del mapa los sirve OpenStreetMap, que puede registrar la dirección IP de quien los solicita.',
    ),
    (
      'Tus derechos (ARCO)',
      'Puedes acceder a tus datos, corregirlos o cancelarlos, y oponerte a su uso. Tu nombre, foto y descripción '
          'se editan desde "Mi perfil"; tus reseñas, desde cada lugar. Para pedir la eliminación de tu cuenta o '
          'cualquier otro derecho, contacta a los administradores de TouristMAR.',
    ),
    (
      'Cambios a este aviso',
      'Si cambiamos este aviso publicaremos la nueva versión en esta misma página con su fecha de actualización.',
    ),
  ];

  @override
  Widget build(BuildContext context) => ThemedBuilder(builder: _build);

  Widget _build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.panelNavy,
      appBar: AppBar(
        backgroundColor: AppColors.panelNavy,
        foregroundColor: AppColors.textPrimary,
        leading: IconButton(
          tooltip: 'Volver',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).canPop() ? Navigator.of(context).pop() : context.go('/'),
        ),
        title: const Text('Aviso de privacidad', style: TextStyle(fontSize: 16)),
      ),
      body: SizedBox.expand(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Aviso de privacidad y cookies', style: AppTypography.h1),
                  const SizedBox(height: 4),
                  Text('Última actualización: $actualizado', style: AppTypography.bodySmall),
                  for (final (titulo, texto) in _secciones) ...[
                    const SizedBox(height: AppSpacing.xl),
                    Text(titulo, style: AppTypography.h3),
                    const SizedBox(height: AppSpacing.sm),
                    Text(texto, style: AppTypography.body.copyWith(fontSize: 15, height: 1.55)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
