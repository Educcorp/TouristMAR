import 'package:flutter/material.dart';

import '../services/recorridos_service.dart';
import '../widgets/recorrido360/visor_360.dart';

/// Recorrido 360° a pantalla completa (web, o móvil sin el módulo de Unity):
/// se entra desde la tarjeta del lugar en el mapa o desde su ficha, como el
/// Street View de Google.
class Recorrido360Page extends StatelessWidget {
  final RecorridoPublico recorrido;
  final String? lugarNombre;

  const Recorrido360Page({super.key, required this.recorrido, this.lugarNombre});


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Visor360(
          escenas: [for (final e in recorrido.escenas) EscenaVisor.publica(e)],
          escenaInicialId: recorrido.escenaInicial,
          titulo: recorrido.titulo,
          subtitulo: lugarNombre != null && lugarNombre != recorrido.titulo ? lugarNombre : null,
          onCerrar: () => Navigator.of(context).maybePop(),
        ),
      ),
    );
  }
}
