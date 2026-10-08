import 'package:flutter/material.dart';

import '../models/lugar.dart';
import '../services/favoritos_service.dart';
import '../theme/app_theme.dart';

/// Rojo del corazón de un lugar que ya está en "Mis favoritos".
const Color colorFavorito = AppColors.rojo;

/// Corazón para marcar o desmarcar [lugar] en "Mis favoritos": vacío si no
/// está guardado y relleno en rojo si sí. Escucha [FavoritosService.ids], así
/// que todas las tarjetas y la ficha del mismo lugar se pintan igual.
///
/// Con [sobreFoto] va en un círculo negro translúcido (para ponerlo encima de
/// una portada); si no, es un ícono simple sobre el fondo de la tarjeta.
class FavoritoButton extends StatelessWidget {
  final Lugar lugar;
  final bool sobreFoto;
  final double size;

  const FavoritoButton({super.key, required this.lugar, this.sobreFoto = true, this.size = 18});

  Future<void> _alternar(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    if (!lugar.esFavoritable) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Este lugar es de ejemplo y aún no se puede guardar en favoritos')),
      );
      return;
    }
    try {
      final marcado = await FavoritosService.instance.alternar(lugar.id);
      messenger.showSnackBar(SnackBar(content: Text(marcado ? 'Agregado a tus favoritos' : 'Quitado de tus favoritos')));
    } on FavoritosError catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Set<String>>(
      valueListenable: FavoritosService.instance.ids,
      builder: (context, ids, _) {
        final esFavorito = ids.contains(lugar.id);
        final icono = Icon(
          esFavorito ? Icons.favorite : Icons.favorite_border,
          size: size,
          color: esFavorito ? colorFavorito : (sobreFoto ? Colors.white : AppColors.slate400),
        );
        return Tooltip(
          message: esFavorito ? 'Quitar de favoritos' : 'Agregar a favoritos',
          child: Material(
            color: sobreFoto ? Colors.black.withValues(alpha: 0.45) : Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => _alternar(context),
              child: Padding(padding: EdgeInsets.all(size / 3), child: icono),
            ),
          ),
        );
      },
    );
  }
}
