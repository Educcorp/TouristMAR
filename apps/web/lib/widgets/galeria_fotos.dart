import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'cover_image.dart';

/// Tira de fotos de la galería de un lugar. Al tocar una se abre en pantalla
/// completa y se puede pasar a las demás deslizando.
class GaleriaFotos extends StatelessWidget {
  final List<String> fotos;
  final double alto;

  const GaleriaFotos({super.key, required this.fotos, this.alto = 120});

  @override
  Widget build(BuildContext context) {
    if (fotos.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: alto,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: fotos.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, i) => ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.button),
          child: Material(
            color: AppColors.surfaceAlt,
            child: InkWell(
              onTap: () => abrirVisorFotos(context, fotos, inicial: i),
              child: SizedBox(width: alto * 4 / 3, child: CoverImage(source: fotos[i])),
            ),
          ),
        ),
      ),
    );
  }
}

/// Visor a pantalla completa de una lista de fotos.
Future<void> abrirVisorFotos(BuildContext context, List<String> fotos, {int inicial = 0}) {
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      pageBuilder: (_, __, ___) => _VisorFotos(fotos: fotos, inicial: inicial),
      transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
    ),
  );
}

class _VisorFotos extends StatefulWidget {
  final List<String> fotos;
  final int inicial;

  const _VisorFotos({required this.fotos, required this.inicial});

  @override
  State<_VisorFotos> createState() => _VisorFotosState();
}

class _VisorFotosState extends State<_VisorFotos> {
  late final _controller = PageController(initialPage: widget.inicial);
  late int _actual = widget.inicial;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _ir(int delta) {
    final destino = (_actual + delta).clamp(0, widget.fotos.length - 1);
    _controller.animateToPage(destino, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final varias = widget.fotos.length > 1;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: widget.fotos.length,
              onPageChanged: (i) => setState(() => _actual = i),
              itemBuilder: (_, i) => InteractiveViewer(
                child: Center(child: CoverImage(source: widget.fotos[i], fit: BoxFit.contain)),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                tooltip: 'Cerrar',
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            if (varias) ...[
              Positioned(
                left: 8,
                top: 0,
                bottom: 0,
                child: Center(
                  child: IconButton(
                    tooltip: 'Anterior',
                    icon: const Icon(Icons.chevron_left, color: Colors.white, size: 36),
                    onPressed: _actual == 0 ? null : () => _ir(-1),
                  ),
                ),
              ),
              Positioned(
                right: 8,
                top: 0,
                bottom: 0,
                child: Center(
                  child: IconButton(
                    tooltip: 'Siguiente',
                    icon: const Icon(Icons.chevron_right, color: Colors.white, size: 36),
                    onPressed: _actual == widget.fotos.length - 1 ? null : () => _ir(1),
                  ),
                ),
              ),
              Positioned(
                bottom: 16,
                left: 0,
                right: 0,
                child: Center(
                  child: Text('${_actual + 1} / ${widget.fotos.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
