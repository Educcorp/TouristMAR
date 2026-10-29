import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/breakpoints.dart';

/// Una cifra del tablero: ícono discreto, el número y qué cuenta.
class CeldaCifra {
  final IconData icon;
  final String valor;
  final String etiqueta;

  /// La cifra pide atención (p. ej. solicitudes pendientes): se marca con la
  /// franja amarilla arriba de la celda.
  final bool alerta;

  const CeldaCifra(this.icon, this.valor, this.etiqueta, {this.alerta = false});
}

/// Las cifras de un panel en una sola tira, como un tablero de salidas:
/// celdas separadas por filetes y números en la letra condensada. Lo usan el
/// panel de empresa, el inicio del admin y los reportes, para que las cifras
/// se lean igual en los tres (antes el admin usaba tarjetas sueltas).
class TableroCifras extends StatelessWidget {
  final List<CeldaCifra> celdas;

  const TableroCifras({super.key, required this.celdas});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columnas = Breakpoints.isCompact(constraints.maxWidth) ? 2 : celdas.length.clamp(1, 4);
        final ancho = constraints.maxWidth / columnas;
        return Container(
          decoration: BoxDecoration(
            color: AppColors.cubierta,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          clipBehavior: Clip.antiAlias,
          child: Wrap(
            children: [
              for (var i = 0; i < celdas.length; i++)
                Container(
                  width: ancho - (i % columnas == columnas - 1 ? 2 : 0),
                  decoration: BoxDecoration(
                    border: Border(
                      right: i % columnas == columnas - 1 ? BorderSide.none : BorderSide(color: AppColors.borderSubtle),
                      top: i >= columnas ? BorderSide(color: AppColors.borderSubtle) : BorderSide.none,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(height: 4, color: celdas[i].alerta ? AppColors.amarillo : Colors.transparent),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(celdas[i].icon, size: 20, color: AppColors.slate400),
                            const SizedBox(height: 8),
                            Text(celdas[i].valor, style: AppTypography.cifra(size: 34)),
                            const SizedBox(height: 2),
                            // Alto fijo de dos renglones: así todas las celdas de
                            // una fila miden lo mismo y los filetes cuadran.
                            SizedBox(
                              height: 38,
                              child: Text(
                                celdas[i].etiqueta,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.bodySmall.copyWith(color: AppColors.slate400, height: 1.25),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
