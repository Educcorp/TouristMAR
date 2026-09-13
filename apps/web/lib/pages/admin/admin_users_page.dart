import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/session_storage.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';

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
    return Scaffold(
      backgroundColor: AppColors.panelNavy,
      appBar: AppBar(
        backgroundColor: AppColors.panelNavy,
        foregroundColor: Colors.white,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Gestión de usuarios'),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.brandTeal.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.brandTeal.withOpacity(0.3)),
              ),
              child: Text('${_users.length}', style: const TextStyle(color: AppColors.brandTeal, fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Buscar por nombre o correo…',
                      hintStyle: const TextStyle(color: AppColors.slate500),
                      prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.slate500),
                      filled: true,
                      fillColor: AppColors.panelNavySoft,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.brandTeal),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(child: _buildContent()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.brandTeal));
    }
    if (_error != null) {
      return Center(child: Text(_error!, style: const TextStyle(color: AppColors.errorRed)));
    }
    final filtered = _filtered;
    if (filtered.isEmpty) {
      return const Center(
        child: Text('No hay usuarios que coincidan con tu búsqueda.', style: TextStyle(color: AppColors.slate400)),
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) => _UserTile(
        user: filtered[i],
        isUpdating: _updating.contains(filtered[i].id),
        onToggleActive: () => _toggleActive(filtered[i]),
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  final AuthUser user;
  final bool isUpdating;
  final VoidCallback onToggleActive;

  const _UserTile({required this.user, required this.isUpdating, required this.onToggleActive});

  @override
  Widget build(BuildContext context) {
    final blocked = !user.activo;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.brandTeal.withOpacity(0.15),
            child: Text(
              user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
              style: const TextStyle(color: AppColors.brandTeal, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                Text(user.email, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.slate400, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _Badge(
                text: user.isNegocio ? 'Empresa' : 'Visitante',
                color: user.isNegocio ? AppColors.businessOrange : AppColors.brandTeal,
              ),
              _Badge(text: blocked ? 'Bloqueado' : 'Activo', color: blocked ? AppColors.errorRed : Colors.greenAccent),
              SizedBox(
                width: 108,
                child: isUpdating
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.slate400))),
                      )
                    : AppButton(
                        variant: AppButtonVariant.ghost,
                        backgroundColor: blocked ? Colors.greenAccent.withOpacity(0.1) : AppColors.errorRed.withOpacity(0.1),
                        foregroundColor: blocked ? Colors.greenAccent : AppColors.errorRed,
                        onPressed: onToggleActive,
                        child: Text(blocked ? 'Desbloquear' : 'Bloquear', style: const TextStyle(fontSize: 12)),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;

  const _Badge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }
}
