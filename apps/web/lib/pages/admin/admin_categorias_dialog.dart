import 'package:flutter/material.dart';

import '../../models/lugar.dart';
import '../../services/auth_service.dart' show AuthError;
import '../../services/categorias_service.dart';
import '../../services/session_storage.dart';
import '../../theme/app_theme.dart';

/// Ventana para administrar las categorías de negocio: las que salen en el
/// desplegable del registro y de "Editar negocio". Renombrar una también
/// cambia los negocios que la tenían; borrarla no toca los negocios.
Future<void> mostrarCategoriasAdmin(BuildContext context, {CategoriasService? service}) {
  return showDialog<void>(context: context, builder: (_) => _CategoriasDialog(service: service ?? CategoriasService()));
}

class _CategoriasDialog extends StatefulWidget {
  final CategoriasService service;

  const _CategoriasDialog({required this.service});

  @override
  State<_CategoriasDialog> createState() => _CategoriasDialogState();
}

class _CategoriasDialogState extends State<_CategoriasDialog> {
  final _nueva = TextEditingController();
  List<CategoriaNegocio>? _categorias;
  String? _error;
  bool _ocupado = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _nueva.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    final token = SessionStorage.token;
    if (token == null) return;
    try {
      final lista = await widget.service.listarAdmin(token);
      if (mounted) setState(() => _categorias = lista);
    } catch (err) {
      if (mounted) setState(() => _error = err is AuthError ? err.message : 'No se pudieron cargar las categorías');
    }
  }

  Future<void> _ejecutar(Future<void> Function(String token) accion) async {
    final token = SessionStorage.token;
    if (token == null) return;
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      await accion(token);
      await _cargar();
    } catch (err) {
      if (mounted) setState(() => _error = err is AuthError ? err.message : 'No se pudo completar la acción');
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _agregar() async {
    final nombre = _nueva.text.trim();
    if (nombre.isEmpty) return;
    await _ejecutar((t) => widget.service.crear(t, nombre));
    if (_error == null) _nueva.clear();
  }

  Future<void> _renombrar(CategoriaNegocio c) async {
    final ctrl = TextEditingController(text: c.nombre);
    final nombre = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panelNavySoft,
        title: Text('Renombrar categoría', style: TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 60,
          style: TextStyle(color: AppColors.textPrimary),
          onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()), child: const Text('Guardar')),
        ],
      ),
    );
    ctrl.dispose();
    if (nombre == null || nombre.isEmpty || nombre == c.nombre) return;
    await _ejecutar((t) => widget.service.renombrar(t, c.id, nombre));
  }

  Future<void> _borrar(CategoriaNegocio c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panelNavySoft,
        title: Text('Quitar "${c.nombre}"', style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          c.negocios == 0
              ? 'Ya no saldrá en la lista de categorías.'
              : 'Ya no saldrá en la lista. Los ${c.negocios} negocios que la usan la conservan hasta que cambien de categoría.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Quitar', style: TextStyle(color: AppColors.errorRed)),
          ),
        ],
      ),
    );
    if (ok == true) await _ejecutar((t) => widget.service.borrar(t, c.id));
  }

  @override
  Widget build(BuildContext context) {
    final lista = _categorias;
    return Dialog(
      backgroundColor: AppColors.panelNavySoft,
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: Text('Categorías de negocio', style: AppTypography.h2)),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, color: AppColors.slate400),
                  ),
                ],
              ),
              Text('Son las opciones que eligen los negocios al registrarse o editar su ficha.',
                  style: AppTypography.bodySmall),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const ValueKey('categoria-nueva'),
                      controller: _nueva,
                      enabled: !_ocupado,
                      maxLength: 60,
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
                      onSubmitted: (_) => _agregar(),
                      decoration: InputDecoration(
                        hintText: 'Nueva categoría (ej. Tour en lancha)',
                        hintStyle: AppTypography.bodySmall,
                        counterText: '',
                        isDense: true,
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.buttonLg)),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  FilledButton.icon(
                    onPressed: _ocupado ? null : _agregar,
                    style: FilledButton.styleFrom(backgroundColor: AppColors.adminViolet),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Agregar'),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(_error!, style: TextStyle(color: AppColors.errorRed, fontSize: 14)),
              ],
              const SizedBox(height: AppSpacing.md),
              Flexible(
                child: lista == null
                    ? const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: lista.length,
                        separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.borderSubtle),
                        itemBuilder: (_, i) {
                          final c = lista[i];
                          final cat = CategoriaLugarDetector.detectar(c.nombre);
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(cat.icon, color: cat.color),
                            title: Text(c.nombre, style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                            subtitle: Text(
                              c.negocios == 1 ? '1 negocio' : '${c.negocios} negocios',
                              style: AppTypography.caption,
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Renombrar',
                                  onPressed: _ocupado ? null : () => _renombrar(c),
                                  icon: Icon(Icons.edit_outlined, size: 18, color: AppColors.slate400),
                                ),
                                IconButton(
                                  tooltip: 'Quitar',
                                  onPressed: _ocupado ? null : () => _borrar(c),
                                  icon: Icon(Icons.delete_outline, size: 18, color: AppColors.errorRed),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
