import 'package:flutter/material.dart';

import '../../models/lugar.dart';
import '../../services/resenas_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/keyboard.dart';
import 'resenas_widgets.dart';

/// "Valoraciones y comentarios" de la ficha de un lugar: resumen de
/// calificaciones, formulario para dejar (o editar) la propia reseña y la
/// lista de reseñas con las respuestas del negocio.
///
/// Solo los negocios reales tienen reseñas; en un lugar de ejemplo se avisa.
/// Con [vistaPrevia] (el negocio o un admin viendo la ficha) no hay formulario.
class ResenasLugarSection extends StatefulWidget {
  final Lugar lugar;
  final bool vistaPrevia;

  /// Avisa el resumen vigente cada vez que se carga o cambia (para que la
  /// cabecera de la ficha muestre el promedio real).
  final ValueChanged<ResumenResenas>? onResumen;

  /// Se llama después de publicar, editar o borrar la reseña propia.
  final VoidCallback? onCambio;

  final ResenasService service;

  ResenasLugarSection({
    super.key,
    required this.lugar,
    this.vistaPrevia = false,
    this.onResumen,
    this.onCambio,
    ResenasService? service,
  }) : service = service ?? ResenasService();

  @override
  State<ResenasLugarSection> createState() => _ResenasLugarSectionState();
}

class _ResenasLugarSectionState extends State<ResenasLugarSection> {
  static const _maxComentario = 1000;

  final _comentario = TextEditingController();
  ResenasLugar? _datos;
  bool _cargando = true;
  String? _error;

  int _estrellas = 0;
  bool _editando = false;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    if (widget.lugar.esFavoritable) {
      _cargar();
    } else {
      _cargando = false;
    }
  }

  @override
  void dispose() {
    _comentario.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final datos = await widget.service.listarDeLugar(widget.lugar.id);
      if (!mounted) return;
      setState(() => _datos = datos);
      widget.onResumen?.call(datos.resumen);
    } on ResenasError catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _empezarEdicion(Resena? existente) {
    setState(() {
      _editando = true;
      _estrellas = existente?.estrellas ?? 0;
      _comentario.text = existente?.comentario ?? '';
    });
  }

  void _cancelarEdicion() {
    hideKeyboard();
    setState(() {
      _editando = false;
      _estrellas = 0;
      _comentario.clear();
    });
  }

  void _aviso(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _publicar() async {
    if (_estrellas == 0) {
      _aviso('Elige de 1 a 5 estrellas');
      return;
    }
    hideKeyboard();
    final texto = _comentario.text.trim();
    setState(() => _guardando = true);
    try {
      await widget.service.guardar(widget.lugar.id, estrellas: _estrellas, comentario: texto.isEmpty ? null : texto);
      if (!mounted) return;
      _cancelarEdicion();
      _aviso('Gracias por tu reseña');
      widget.onCambio?.call();
      await _cargar();
    } on ResenasError catch (e) {
      if (mounted) _aviso(e.message);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _eliminar() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.panelNavySoft,
        title: Text('Eliminar tu reseña', style: TextStyle(color: AppColors.textPrimary)),
        content: Text('Se quitará tu calificación y tu comentario de este lugar.',
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('Cancelar', style: TextStyle(color: AppColors.slate400)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Eliminar', style: TextStyle(color: AppColors.rojo, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;
    try {
      await widget.service.borrar(widget.lugar.id);
      if (!mounted) return;
      _aviso('Reseña eliminada');
      widget.onCambio?.call();
      await _cargar();
    } on ResenasError catch (e) {
      if (mounted) _aviso(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Valoraciones y comentarios', style: AppTypography.h3),
        const SizedBox(height: AppSpacing.md),
        _contenido(),
      ],
    );
  }

  Widget _contenido() {
    if (!widget.lugar.esFavoritable) {
      return const _Aviso(icon: Icons.science_outlined, texto: 'Este lugar es de ejemplo y aún no tiene reseñas reales.');
    }
    if (_cargando && _datos == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final datos = _datos;
    if (datos == null) {
      return _Aviso(
        icon: Icons.cloud_off_outlined,
        texto: _error ?? 'No se pudieron cargar las reseñas',
        accion: TextButton(onPressed: _cargar, child: const Text('Reintentar')),
      );
    }

    final mia = datos.mia;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ResumenResenasCard(resumen: datos.resumen),
        const SizedBox(height: AppSpacing.lg),
        if (!widget.vistaPrevia && (_editando || mia == null)) ...[
          _formulario(mia),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (datos.resenas.isEmpty)
          const _Aviso(icon: Icons.forum_outlined, texto: 'Todavía no hay reseñas. ¡Sé el primero en opinar!')
        else
          ...datos.resenas.map(
            (r) => ResenaTile(
              resena: r,
              acciones: r.mia && !widget.vistaPrevia && !_editando
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () => _empezarEdicion(r),
                          icon: const Icon(Icons.edit_outlined, size: 15),
                          label: const Text('Editar'),
                        ),
                        TextButton.icon(
                          onPressed: _eliminar,
                          icon: const Icon(Icons.delete_outline, size: 15),
                          label: const Text('Eliminar'),
                          style: TextButton.styleFrom(foregroundColor: AppColors.rojo),
                        ),
                      ],
                    )
                  : null,
            ),
          ),
      ],
    );
  }

  Widget _formulario(Resena? existente) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(existente == null ? 'Deja tu reseña' : 'Edita tu reseña', style: AppTypography.h3),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: List.generate(5, (i) {
              final valor = i + 1;
              return IconButton(
                tooltip: '$valor ${valor == 1 ? 'estrella' : 'estrellas'}',
                visualDensity: VisualDensity.compact,
                onPressed: _guardando ? null : () => setState(() => _estrellas = valor),
                icon: Icon(
                  valor <= _estrellas ? Icons.star : Icons.star_border,
                  size: 30,
                  color: valor <= _estrellas ? Colors.amber : AppColors.slate500,
                ),
              );
            }),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _comentario,
            enabled: !_guardando,
            minLines: 3,
            maxLines: 6,
            maxLength: _maxComentario,
            onTapOutside: (_) => hideKeyboard(),
            style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Cuéntanos tu experiencia (opcional)',
              hintStyle: TextStyle(color: AppColors.slate500),
              filled: true,
              fillColor: AppColors.surfaceAlt,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.buttonLg),
                borderSide: BorderSide(color: AppColors.borderSubtle),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (_editando)
                TextButton(
                  onPressed: _guardando ? null : _cancelarEdicion,
                  child: Text('Cancelar', style: TextStyle(color: AppColors.slate400)),
                ),
              const SizedBox(width: AppSpacing.sm),
              FilledButton(
                onPressed: _guardando ? null : _publicar,
                child: _guardando
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(existente == null ? 'Publicar reseña' : 'Guardar cambios'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  final IconData icon;
  final String texto;
  final Widget? accion;

  const _Aviso({required this.icon, required this.texto, this.accion});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.slate400, size: 28),
          const SizedBox(height: AppSpacing.sm),
          Text(texto, textAlign: TextAlign.center, style: AppTypography.body),
          if (accion != null) accion!,
        ],
      ),
    );
  }
}
