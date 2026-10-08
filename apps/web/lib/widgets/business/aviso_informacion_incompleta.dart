import 'package:flutter/material.dart';

import '../../models/business_profile.dart';
import '../../theme/app_theme.dart';
import '../app_button.dart';

/// Texto que aparece cuando la empresa intenta salir sin completar su
/// información (tocar fuera del aviso, "atrás", "Volver"…).
const mensajeCompletarPrimero = 'Primero tienes que completar la información de tu negocio para continuar.';

/// Muestra el aviso obligatorio "Completa la información de tu negocio".
///
/// No se puede cerrar: tocar fuera o "atrás" solo muestra
/// [mensajeCompletarPrimero]. Regresa true si eligió "Completar mi
/// información" y false si eligió "Cerrar sesión".
Future<bool?> mostrarAvisoInformacionIncompleta(BuildContext context, BusinessProfile negocio) {
  return showDialog<bool>(
    context: context,
    // Se deja "dismissible" para que el toque afuera llegue al PopScope del
    // aviso, que no lo deja cerrar y en cambio muestra el mensaje.
    barrierDismissible: true,
    builder: (_) => AvisoInformacionIncompleta(negocio: negocio),
  );
}

class AvisoInformacionIncompleta extends StatefulWidget {
  final BusinessProfile negocio;

  const AvisoInformacionIncompleta({super.key, required this.negocio});

  @override
  State<AvisoInformacionIncompleta> createState() => _AvisoInformacionIncompletaState();
}

class _AvisoInformacionIncompletaState extends State<AvisoInformacionIncompleta> {
  bool _intentoSalir = false;

  @override
  Widget build(BuildContext context) {
    final faltantes = widget.negocio.datosFaltantes;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _intentoSalir = true);
      },
      child: Dialog(
        backgroundColor: AppColors.panelNavySoft,
        insetPadding: const EdgeInsets.all(AppSpacing.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.storefront_outlined, size: 36, color: AppColors.businessOrange),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Completa la información de tu negocio',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Para continuar en TouristMAR es necesario que completes la ficha de '
                  '"${widget.negocio.businessName}". Con esta información los visitantes '
                  'podrán encontrar tu negocio en el mapa y saber cuándo visitarlo.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.slate300, fontSize: 14, height: 1.4),
                ),
                if (faltantes.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text('Información pendiente:', style: TextStyle(color: AppColors.slate400, fontSize: 13)),
                  const SizedBox(height: 6),
                  for (final dato in faltantes)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Icon(Icons.radio_button_unchecked, size: 14, color: AppColors.businessOrange),
                          const SizedBox(width: 8),
                          Expanded(child: Text(dato, style: TextStyle(color: AppColors.textPrimary, fontSize: 13))),
                        ],
                      ),
                    ),
                ],
                if (_intentoSalir) ...[
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    key: const ValueKey('aviso-completar-primero'),
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.amber.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      mensajeCompletarPrimero,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.amber, fontSize: 13),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                AppButton(
                  backgroundColor: AppColors.businessOrange,
                  foregroundColor: Colors.white,
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Completar mi información'),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text('Cerrar sesión', style: TextStyle(color: AppColors.slate400, fontSize: 13)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
