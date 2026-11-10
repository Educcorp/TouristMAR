import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../theme/app_theme.dart';

/// Deja acomodar una foto recién elegida antes de subirla: se arrastra y se
/// hace zoom dentro de un marco con la proporción en que se va a mostrar
/// ([aspecto] = ancho / alto). Devuelve la parte encuadrada como PNG, o null
/// si se cancela.
Future<Uint8List?> recortarImagen(
  BuildContext context,
  Uint8List bytes, {
  double aspecto = 16 / 9,
  String titulo = 'Ajusta la foto',
  /// Ancho en píxeles de la imagen que se genera.
  double anchoSalida = 1600,
}) {
  return showDialog<Uint8List>(
    context: context,
    builder: (_) => _RecortarDialog(bytes: bytes, aspecto: aspecto, titulo: titulo, anchoSalida: anchoSalida),
  );
}

class _RecortarDialog extends StatefulWidget {
  final Uint8List bytes;
  final double aspecto;
  final String titulo;
  final double anchoSalida;

  const _RecortarDialog({required this.bytes, required this.aspecto, required this.titulo, required this.anchoSalida});

  @override
  State<_RecortarDialog> createState() => _RecortarDialogState();
}

class _RecortarDialogState extends State<_RecortarDialog> {
  final _marco = GlobalKey();
  final _transform = TransformationController();
  bool _procesando = false;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  Future<void> _usar() async {
    setState(() => _procesando = true);
    try {
      final boundary = _marco.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final imagen = await boundary.toImage(pixelRatio: widget.anchoSalida / boundary.size.width);
      final png = await imagen.toByteData(format: ui.ImageByteFormat.png);
      imagen.dispose();
      if (!mounted) return;
      Navigator.of(context).pop(png?.buffer.asUint8List());
    } catch (_) {
      // Si el navegador no deja leer el lienzo, se usa la foto tal cual.
      if (mounted) Navigator.of(context).pop(widget.bytes);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.panelNavySoft,
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.titulo, style: AppTypography.h3),
              const SizedBox(height: 4),
              Text('Arrastra para mover y usa la rueda o dos dedos para acercar.', style: AppTypography.bodySmall),
              const SizedBox(height: 16),
              AspectRatio(
                aspectRatio: widget.aspecto,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: RepaintBoundary(
                    key: _marco,
                    child: ColoredBox(
                      color: Colors.black,
                      child: InteractiveViewer(
                        transformationController: _transform,
                        minScale: 1,
                        maxScale: 5,
                        constrained: true,
                        child: SizedBox.expand(child: Image.memory(widget.bytes, fit: BoxFit.cover)),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: _procesando ? null : () => _transform.value = Matrix4.identity(),
                    icon: const Icon(Icons.restart_alt, size: 18),
                    label: const Text('Restablecer'),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _procesando ? null : () => Navigator.of(context).pop(),
                    child: Text('Cancelar', style: TextStyle(color: AppColors.slate400)),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    key: const ValueKey('recortar-usar'),
                    onPressed: _procesando ? null : _usar,
                    child: Text(_procesando ? 'Procesando…' : 'Usar esta foto'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
