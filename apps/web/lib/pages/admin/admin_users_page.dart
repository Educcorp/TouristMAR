import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/session_storage.dart';
import '../../theme/app_theme.dart';
import '../../theme/breakpoints.dart';
import '../../widgets/admin/ds_badge.dart';
import '../../widgets/admin/ds_card.dart';
import '../../widgets/admin/ds_states.dart';
import '../../widgets/admin/ds_table.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/aviso.dart';

/// Contenido de la sección "Usuarios" embebido en [AdminShell].
class AdminUsersPage extends StatefulWidget {
  final AuthService authService;

  AdminUsersPage({super.key, AuthService? authService}) : authService = authService ?? AuthService();

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  final _searchController = TextEditingController();
  List<AuthUser> _users = [];
  bool _loading = true;
  String? _error;
  final Set<String> _updating = {};

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final token = SessionStorage.token;
    if (token == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final users = await widget.authService.adminListUsers(token);
      if (!mounted) return;
      setState(() => _users = users);
    } catch (err) {
      if (!mounted) return;
      setState(() => _error = err is AuthError ? err.message : 'No se pudo conectar con el servidor');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleActive(AuthUser user) async {
    final token = SessionStorage.token;
    if (token == null) return;
    setState(() => _updating.add(user.id));
    try {
      final updated = await widget.authService.adminSetUserActive(token, user.id, !user.activo);
      if (!mounted) return;
      setState(() {
        final idx = _users.indexWhere((u) => u.id == user.id);
        if (idx != -1) _users[idx] = updated;
      });
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        aviso(err is AuthError ? err.message : 'No se pudo actualizar el usuario', tipo: AvisoTipo.error),
      );
    } finally {
      if (mounted) setState(() => _updating.remove(user.id));
    }
  }

  Future<void> _editar(AuthUser user) async {
    final actualizado = await showDialog<AuthUser>(
      context: context,
      builder: (_) => _EditarUsuarioDialog(user: user, authService: widget.authService),
    );
    if (actualizado == null || !mounted) return;
    setState(() {
      final idx = _users.indexWhere((u) => u.id == user.id);
      if (idx != -1) _users[idx] = actualizado;
    });
    ScaffoldMessenger.of(context).showSnackBar(aviso('Usuario actualizado'));
  }

  List<AuthUser> get _filtered {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _users;
    return _users.where((u) => u.name.toLowerCase().contains(query) || u.email.toLowerCase().contains(query)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.adminViolet,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Usuarios', style: AppTypography.h1),
                const SizedBox(width: AppSpacing.sm),
                DsBadge(text: '${_users.length}', tone: BadgeTone.info),
              ],
            ),
            const SizedBox(height: 4),
            Text('Administra los usuarios del sistema.', style: AppTypography.body),
            const SizedBox(height: AppSpacing.lg),
            _SearchField(controller: _searchController),
            const SizedBox(height: AppSpacing.xl),
            _buildContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) return DsLoadingState();
    if (_error != null) return DsErrorState(message: _error!, onRetry: _load);
    final filtered = _filtered;
    if (filtered.isEmpty) {
      return const DsEmptyState(
        icon: Icons.person_search_outlined,
        title: 'Sin coincidencias',
        subtitle: 'Ningún usuario coincide con tu búsqueda.',
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Umbral bajo a propósito: este ancho ya es el del área de contenido
        // (con el sidebar de 260px y el padding ya descontados), no el de la
        // ventana completa — un desktop normal cae por debajo de
        // `Breakpoints.expanded` una vez restado el sidebar.
        if (constraints.maxWidth >= Breakpoints.compact) {
          return DsTable(
            headers: const ['Usuario', 'Rol', 'Estado', 'Acciones'],
            columnFlex: const [4, 2, 2, 3],
            rows: filtered
                .map((u) => DsTableRow(
                      columnFlex: const [4, 2, 2, 3],
                      cells: [
                        _IdentityCell(user: u),
                        DsBadge(
                          text: u.isNegocio ? 'Empresa' : 'Visitante',
                          tone: BadgeTone.neutral,
                          icon: u.isNegocio ? Icons.storefront_outlined : Icons.person_outline,
                        ),
                        DsBadge(
                          text: u.activo ? 'Activo' : 'Bloqueado',
                          tone: u.activo ? BadgeTone.success : BadgeTone.danger,
                        ),
                        _ActionCell(
                          blocked: !u.activo,
                          isUpdating: _updating.contains(u.id),
                          onToggleActive: () => _toggleActive(u),
                          onEdit: () => _editar(u),
                        ),
                      ],
                    ))
                .toList(),
          );
        }

        return Column(
          children: filtered
              .map((u) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: _UserCard(
                      user: u,
                      isUpdating: _updating.contains(u.id),
                      onToggleActive: () => _toggleActive(u),
                      onEdit: () => _editar(u),
                    ),
                  ))
              .toList(),
        );
      },
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  const _SearchField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: TextField(
        controller: controller,
        style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Buscar por nombre o correo…',
          hintStyle: AppTypography.bodySmall,
          prefixIcon: Icon(Icons.search, size: 18, color: AppColors.slate500),
          filled: true,
          fillColor: AppColors.surface,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.buttonLg),
            borderSide: BorderSide(color: AppColors.borderSubtle),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.buttonLg),
            borderSide: BorderSide(color: AppColors.borderSubtle),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.buttonLg),
            borderSide: BorderSide(color: AppColors.adminViolet),
          ),
        ),
      ),
    );
  }
}

class _IdentityCell extends StatelessWidget {
  final AuthUser user;
  const _IdentityCell({required this.user});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        UserAvatar(fallbackLetter: user.name, imageUrl: user.avatarUrl, radius: 18, color: AppColors.brandTeal),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(user.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
              Text(user.email, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

/// Acciones de una fila: editar los datos y un interruptor para activar o
/// bloquear la cuenta.
class _ActionCell extends StatelessWidget {
  final bool blocked;
  final bool isUpdating;
  final VoidCallback onToggleActive;
  final VoidCallback onEdit;

  const _ActionCell({required this.blocked, required this.isUpdating, required this.onToggleActive, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Editar usuario',
          onPressed: isUpdating ? null : onEdit,
          icon: Icon(Icons.edit_outlined, size: 20, color: AppColors.slate300),
        ),
        const SizedBox(width: 4),
        if (isUpdating)
          SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.slate400))
        else
          Tooltip(
            message: blocked ? 'Cuenta bloqueada: actívala' : 'Cuenta activa: bloquéala',
            child: Switch(
              value: !blocked,
              onChanged: (_) => onToggleActive(),
              activeThumbColor: Colors.white,
              activeTrackColor: AppColors.emerald,
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: AppColors.rojoTexto.withValues(alpha: 0.7),
              trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
            ),
          ),
      ],
    );
  }
}

class _UserCard extends StatelessWidget {
  final AuthUser user;
  final bool isUpdating;
  final VoidCallback onToggleActive;
  final VoidCallback onEdit;

  const _UserCard({required this.user, required this.isUpdating, required this.onToggleActive, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final blocked = !user.activo;
    return DsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _IdentityCell(user: user),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    DsBadge(
                      text: user.isNegocio ? 'Empresa' : 'Visitante',
                      tone: BadgeTone.neutral,
                      icon: user.isNegocio ? Icons.storefront_outlined : Icons.person_outline,
                    ),
                    DsBadge(text: blocked ? 'Bloqueado' : 'Activo', tone: blocked ? BadgeTone.danger : BadgeTone.success),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _ActionCell(blocked: blocked, isUpdating: isUpdating, onToggleActive: onToggleActive, onEdit: onEdit),
            ],
          ),
        ],
      ),
    );
  }
}

/// Formulario para corregir el nombre y el correo de una cuenta.
class _EditarUsuarioDialog extends StatefulWidget {
  final AuthUser user;
  final AuthService authService;

  const _EditarUsuarioDialog({required this.user, required this.authService});

  @override
  State<_EditarUsuarioDialog> createState() => _EditarUsuarioDialogState();
}

class _EditarUsuarioDialogState extends State<_EditarUsuarioDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _nombre = TextEditingController(text: widget.user.name);
  late final _correo = TextEditingController(text: widget.user.email);
  bool _guardando = false;
  String? _error;

  static final _formatoCorreo = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void dispose() {
    _nombre.dispose();
    _correo.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    final token = SessionStorage.token;
    if (token == null) return;
    final nombre = _nombre.text.trim();
    final correo = _correo.text.trim();
    if (nombre == widget.user.name && correo == widget.user.email) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final actualizado = await widget.authService.adminUpdateUser(
        token,
        widget.user.id,
        nombres: nombre == widget.user.name ? null : nombre,
        email: correo == widget.user.email ? null : correo,
      );
      if (mounted) Navigator.of(context).pop(actualizado);
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _error = err is AuthError ? err.message : 'No se pudo guardar';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.panelNavySoft,
      title: Text('Editar usuario', style: TextStyle(color: AppColors.textPrimary)),
      content: SizedBox(
        width: 380,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                label: 'Nombre',
                icon: Icons.person_outline,
                controller: _nombre,
                accentColor: AppColors.adminViolet,
                validator: (v) => (v ?? '').trim().isEmpty ? 'Escribe un nombre' : null,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: 'Correo',
                icon: Icons.mail_outline,
                controller: _correo,
                keyboardType: TextInputType.emailAddress,
                accentColor: AppColors.adminViolet,
                validator: (v) => _formatoCorreo.hasMatch((v ?? '').trim()) ? null : 'Correo no válido',
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(_error!, style: TextStyle(color: AppColors.errorRed, fontSize: 14)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _guardando ? null : () => Navigator.of(context).pop(),
          child: Text('Cancelar', style: TextStyle(color: AppColors.slate400)),
        ),
        FilledButton(
          onPressed: _guardando ? null : _guardar,
          child: _guardando
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Guardar'),
        ),
      ],
    );
  }
}
