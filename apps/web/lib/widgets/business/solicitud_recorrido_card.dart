import 'package:flutter/material.dart';

import '../../services/recorridos_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/date_format_es.dart';

/// Bloque "Recorrido 360°" de "Editar negocio". Según [estado]:
/// - ya tiene recorrido → solo lo confirma;
/// - solicitud pendiente → avisa que está en revisión;
/// - si no → botón para solicitarlo, que pide tener el pin en el mapa.
///   [pinGuardado] = el pin del formulario ya está guardado; si no, el botón
///   guarda primero ("Guardar y solicitar…"), ver [onSolicitar].
class SolicitudRecorridoCard extends StatelessWidget {
  /// null = cargando.
  final EstadoRecorridoNegocio? estado;
  final bool tienePin;
  final bool pinGuardado;
  final bool ocupado;
  final VoidCallback onSolicitar;

  const SolicitudRecorridoCard({
    super.key,
    required this.estado,
    required this.tienePin,
    required this.pinGuardado,
    required this.ocupado,
    required this.onSolicitar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.panelNavySoft,
        borderRadius: BorderRadius.circular(AppRadius.button),
        border: Border.all(color: AppColors.overlay(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.threesixty, size: 18, color: AppColors.businessOrange),
              const SizedBox(width: 8),
              Text('Recorrido 360°', style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 8),
          ..._contenido(),
        ],
      ),
    );
  }

  List<Widget> _contenido() {
    final e = estado;
    if (e == null) {
      return [
        const SizedBox(height: 4),
        const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
      ];
    }
    if (e.tieneRecorrido) {
      return [
        _Aviso(
          icon: Icons.check_circle_outline,
          color: AppColors.emerald,
          texto: 'Tu negocio ya cuenta con un recorrido 360°. Los visitantes lo verán en el mapa y en tu ficha.',
        ),
      ];
    }
    final s = e.solicitud;
    if (s != null && s.pendiente) {
      return [
        _Aviso(
          icon: Icons.schedule_outlined,
          color: AppColors.amber,
          texto: 'Solicitud enviada el ${formatDateEs(s.creadaEn)}. Un administrador la revisará '
              'y te avisaremos cuando tu recorrido esté listo.',
        ),
      ];
    }
    return [
      if (s != null && s.estado == EstadoSolicitudRecorrido.rechazada) ...[
        _Aviso(
          icon: Icons.info_outline,
          color: AppColors.errorRed,
          texto: s.nota.isEmpty
              ? 'Tu solicitud anterior no se aprobó. Puedes volver a enviarla.'
              : 'Tu solicitud anterior no se aprobó: ${s.nota}',
        ),
        const SizedBox(height: 8),
      ],
      Text(
        tienePin
            ? 'Pide que nuestro equipo tome las fotos 360° de tu negocio. Un administrador recibirá tu solicitud con la ubicación que marcaste.'
            : 'Marca tu negocio en el mapa para poder solicitar su recorrido 360°.',
        style: AppTypography.bodySmall,
      ),
      if (tienePin) ...[
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: ocupado ? null : onSolicitar,
            icon: const Icon(Icons.send_outlined, size: 16),
            label: Text(
              pinGuardado ? 'Solicitar recorrido 360°' : 'Guardar y solicitar recorrido 360°',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.businessOrange,
              side: BorderSide(color: AppColors.businessOrange),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
            ),
          ),
        ),
      ],
    ];
  }
}

class _Aviso extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String texto;

  const _Aviso({required this.icon, required this.color, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(texto, style: TextStyle(color: color, fontSize: 13))),
      ],
    );
  }
}
