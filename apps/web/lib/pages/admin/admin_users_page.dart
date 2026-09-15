import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/session_storage.dart';
import '../../theme/app_theme.dart';
import '../../theme/breakpoints.dart';
import '../../widgets/admin/ds_badge.dart';
import '../../widgets/admin/ds_button.dart';
import '../../widgets/admin/ds_card.dart';
import '../../widgets/admin/ds_states.dart';
import '../../widgets/admin/ds_table.dart';
import '../../widgets/user_avatar.dart';

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
        SnackBar(content: Text(err is AuthError ? err.message : 'No se pudo actualizar el usuario')),
      );
    } finally {
      if (mounted) setState(() => _updating.remove(user.id));
    }
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
            SizedBox(height: AppSpacing.xl),
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
            columnFlex: const [4, 2, 2, 2],
            rows: filtered
                .map((u) => DsTableRow(
                      columnFlex: const [4, 2, 2, 2],
                      cells: [
                        _IdentityCell(user: u),
                        DsBadge(
                          text: u.isNegocio ? 'Empresa' : 'Visitante',
                          tone: u.isNegocio ? BadgeTone.warning : BadgeTone.info,
                        ),
                        DsBadge(
                          text: u.activo ? 'Activo' : 'Bloqueado',
                          tone: u.activo ? BadgeTone.success : BadgeTone.danger,
                        ),
                        _ActionCell(
                          blocked: !u.activo,
                          isUpdating: _updating.contains(u.id),
                          onToggleActive: () => _toggleActive(u),
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
        UserAvatar(fallbackLetter: user.name, imageUrl: user.avatarUrl, radius: 16, color: AppColors.brandTeal),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(user.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
              Text(user.email, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionCell extends StatelessWidget {
  final bool blocked;
  final bool isUpdating;
  final VoidCallback onToggleActive;

  const _ActionCell({required this.blocked, required this.isUpdating, required this.onToggleActive});

  @override
  Widget build(BuildContext context) {
    if (isUpdating) {
      return SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.slate400));
    }
    return DsButton(
      label: blocked ? 'Desbloquear' : 'Bloquear',
      variant: blocked ? DsButtonVariant.secondary : DsButtonVariant.danger,
      accent: blocked ? AppColors.emerald : null,
      size: DsButtonSize.sm,
      onPressed: onToggleActive,
    );
  }
}

class _UserCard extends StatelessWidget {
  final AuthUser user;
  final bool isUpdating;
  final VoidCallback onToggleActive;

  const _UserCard({required this.user, required this.isUpdating, required this.onToggleActive});

  @override
  Widget build(BuildContext context) {
    final blocked = !user.activo;
    return DsCard(
      child: Row(
        children: [
          _IdentityCell(user: user),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Wrap(
                spacing: 6,
                children: [
                  DsBadge(text: user.isNegocio ? 'Empresa' : 'Visitante', tone: user.isNegocio ? BadgeTone.warning : BadgeTone.info),
                  DsBadge(text: blocked ? 'Bloqueado' : 'Activo', tone: blocked ? BadgeTone.danger : BadgeTone.success),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              _ActionCell(blocked: blocked, isUpdating: isUpdating, onToggleActive: onToggleActive),
            ],
          ),
        ],
      ),
    );
  }
}
