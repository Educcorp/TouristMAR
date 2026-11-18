import 'package:flutter/material.dart';

import '../../utils/imprimir_marcador.dart';
import '../../widgets/aviso.dart';

/// El marcador solo, listo para imprimir: fondo blanco, el nombre del lugar
/// al que pertenece y la imagen a todo lo que dé la pantalla (sin recortar ni
/// encimar nada, para que la cámara la reconozca igual que la original). En
/// la web, "Imprimir" abre el diálogo del navegador con una hoja limpia; en
/// el teléfono se puede capturar la pantalla.
class MarcadorImprimiblePage extends StatelessWidget {
  final String imagenUrl;

  /// Nombre del lugar (o el título del marcador si es uno general).
  final String lugar;

  /// Título del marcador, si es distinto del lugar.
  final String? titulo;

  const MarcadorImprimiblePage({super.key, required this.imagenUrl, required this.lugar, this.titulo});

  static Future<void> abrir(BuildContext context, {required String imagenUrl, required String lugar, String? titulo}) {
    return Navigator.of(context).push(MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => MarcadorImprimiblePage(imagenUrl: imagenUrl, lugar: lugar, titulo: titulo),
    ));
  }

  void _imprimir(BuildContext context) {
    final ok = imprimirMarcador(imagenUrl: imagenUrl, lugar: lugar, titulo: titulo);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        aviso('El navegador bloqueó la ventana de impresión. Permite las ventanas emergentes e inténtalo de nuevo.'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const tinta = Color(0xFF0B2A3A);
    final subtitulo = titulo == null || titulo!.trim().isEmpty || titulo!.trim() == lugar.trim() ? null : titulo!.trim();
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: tinta,
        elevation: 0,
        title: const Text('Marcador para imprimir', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        actions: [
          if (puedeImprimirMarcador)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton.icon(
                key: const ValueKey('imprimir-marcador'),
                onPressed: () => _imprimir(context),
                icon: const Icon(Icons.print_outlined, size: 18),
                label: const Text('Imprimir'),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            children: [
              Text(
                lugar,
                textAlign: TextAlign.center,
                style: const TextStyle(color: tinta, fontSize: 26, fontWeight: FontWeight.w800, height: 1.15),
              ),
              if (subtitulo != null) ...[
                const SizedBox(height: 6),
                Text(subtitulo, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF4A5A63), fontSize: 15)),
              ],
              const SizedBox(height: 20),
              Expanded(
                child: Center(
                  child: Image.network(
                    imagenUrl,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                    loadingBuilder: (context, child, progreso) =>
                        progreso == null ? child : const CircularProgressIndicator(),
                    errorBuilder: (_, __, ___) => const Text(
                      'No se pudo cargar la imagen del marcador.',
                      style: TextStyle(color: Color(0xFF4A5A63)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
