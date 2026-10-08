import 'package:flutter/material.dart';

import '../models/business_profile.dart';
import '../services/resenas_service.dart';
import '../theme/app_theme.dart';
import '../utils/keyboard.dart';
import '../widgets/admin/ds_states.dart';
import '../widgets/resenas/resenas_widgets.dart';

/// Contenido de la sección "Reseñas" embebido en [BusinessShell] — sin
/// Scaffold/AppBar propio, igual que las páginas del panel admin. Muestra las
/// reseñas reales del negocio y deja responderlas.
class BusinessReviewsContent extends StatefulWidget {
  final BusinessProfile business;
  final ResenasService service;

  BusinessReviewsContent({super.key, required this.business, ResenasService? service})
      : service = service ?? ResenasService();

  @override
  State<BusinessReviewsContent> createState() => _BusinessReviewsContentState();
}

class _BusinessReviewsContentState extends State<BusinessReviewsContent> {
  ResenasLugar? _datos;
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.business.verified) {
      _cargar();
    } else {
      _cargando = false;
    }
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    final datos = await widget.business.cargarResenas(widget.service);
    if (!mounted) return;
    setState(() {
      _datos = datos ?? _datos;
      _error = datos == null ? 'No se pudieron cargar las reseñas' : null;
      _cargando = false;
    });
  }

  void _aviso(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _responder(Resena resena) async {
    final texto = await showDialog<String>(
      context: context,
      builder: (_) => _RespuestaDialog(inicial: resena.respuesta ?? ''),
    );
    if (texto == null || !mounted) return;
    try {
      await widget.service.responder(resena.id, texto);
      if (!mounted) return;
      _aviso('Respuesta publicada');
      await _cargar();
    } on ResenasError catch (e) {
      if (mounted) _aviso(e.message);
    }
  }

  Future<void> _quitarRespuesta(Resena resena) async {
    try {
      await widget.service.quitarRespuesta(resena.id);
      if (!mounted) return;
      _aviso('Respuesta eliminada');
      await _cargar();
    } on ResenasError catch (e) {
      if (mounted) _aviso(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Reseñas de clientes', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 20)),
                const SizedBox(height: 16),
                _contenido(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _contenido() {
    if (!widget.business.verified) {
      return const DsEmptyState(
        icon: Icons.forum_outlined,
        title: 'Aún no hay reseñas',
        subtitle: 'Este negocio todavía no está activo en el mapa.',
      );
    }
    if (_cargando && _datos == null) {
      return const Padding(padding: EdgeInsets.symmetric(vertical: 48), child: Center(child: CircularProgressIndicator()));
    }
    final datos = _datos;
    if (datos == null) {
      return Column(
        children: [
          DsEmptyState(icon: Icons.cloud_off_outlined, title: _error ?? 'No se pudieron cargar las reseñas', subtitle: ''),
          TextButton(onPressed: _cargar, child: const Text('Reintentar')),
        ],
      );
    }
    if (datos.resenas.isEmpty) {
      return const DsEmptyState(
        icon: Icons.forum_outlined,
        title: 'Aún no hay reseñas',
        subtitle: 'Cuando un visitante califique tu negocio, aparecerá aquí.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ResumenResenasCard(resumen: datos.resumen),
        const SizedBox(height: 20),
        ...datos.resenas.map(
          (r) => ResenaTile(
            resena: r,
            acciones: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (r.respuesta != null && r.respuesta!.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => _quitarRespuesta(r),
                    icon: const Icon(Icons.delete_outline, size: 15),
                    label: const Text('Quitar respuesta'),
                    style: TextButton.styleFrom(foregroundColor: AppColors.rojo),
                  ),
                TextButton.icon(
                  onPressed: () => _responder(r),
                  icon: const Icon(Icons.reply, size: 15),
                  label: Text(r.respuesta == null || r.respuesta!.isEmpty ? 'Responder' : 'Editar respuesta'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Cuadro para escribir (o editar) la respuesta pública a una reseña.
class _RespuestaDialog extends StatefulWidget {
  final String inicial;

  const _RespuestaDialog({required this.inicial});

  @override
  State<_RespuestaDialog> createState() => _RespuestaDialogState();
}

class _RespuestaDialogState extends State<_RespuestaDialog> {
  late final _controller = TextEditingController(text: widget.inicial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vacia = _controller.text.trim().isEmpty;
    return AlertDialog(
      backgroundColor: AppColors.panelNavySoft,
      title: Text('Responder reseña', style: TextStyle(color: AppColors.textPrimary)),
      content: SizedBox(
        width: 420,
        child: TextField(
          controller: _controller,
          autofocus: true,
          minLines: 3,
          maxLines: 6,
          maxLength: 1000,
          onChanged: (_) => setState(() {}),
          onTapOutside: (_) => hideKeyboard(),
          style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Escribe una respuesta pública y amable',
            hintStyle: TextStyle(color: AppColors.slate500),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancelar', style: TextStyle(color: AppColors.slate400)),
        ),
        TextButton(
          onPressed: vacia ? null : () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('Publicar', style: TextStyle(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}
