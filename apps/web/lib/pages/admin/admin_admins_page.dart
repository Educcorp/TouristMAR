import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/session_storage.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin/ds_badge.dart';
import '../../widgets/admin/ds_button.dart';
import '../../widgets/admin/ds_card.dart';
import '../../widgets/admin/ds_states.dart';
import '../../widgets/app_text_field.dart';

/// Contenido de la sección "Admins" embebido en [AdminShell].
class AdminAdminsPage extends StatefulWidget {
  final AuthUser currentAdmin;
  final AuthService authService;

  AdminAdminsPage({super.key, required this.currentAdmin, AuthService? authService})
      : authService = authService ?? AuthService();

  @override
  State<AdminAdminsPage> createState() => _AdminAdminsPageState();
}

class _AdminAdminsPageState extends State<AdminAdminsPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  List<AdminAccount> _admins = [];
  bool _loading = true;
  bool _creating = false;
  bool _showForm = false;
  String? _error;
  String? _formError;
  final Set<String> _deleting = {};

  bool get _canManage => widget.currentAdmin.isSuperAdmin;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
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
      final admins = await widget.authService.adminListAdmins(token);
      if (!mounted) return;
      setState(() => _admins = admins);
    } catch (err) {
      if (!mounted) return;
      setState(() => _error = err is AuthError ? err.message : 'No se pudo conectar con el servidor');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createAdmin() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final token = SessionStorage.token;
    if (token == null) return;

    setState(() {
      _creating = true;
      _formError = null;
    });
    try {
      final admin = await widget.authService.adminCreateAdmin(
        token,
        email: _emailController.text.trim(),
        password: _passwordController.text,
        nombres: _nameController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _admins = [..._admins, admin];
        _showForm = false;
        _nameController.clear();
        _emailController.clear();
        _passwordController.clear();
      });
    } catch (err) {
      if (!mounted) return;
      setState(() => _formError = err is AuthError ? err.message : 'No se pudo crear el administrador');
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _deleteAdmin(AdminAccount admin) async {
    final token = SessionStorage.token;
    if (token == null) return;
    setState(() => _deleting.add(admin.id));
    try {
      await widget.authService.adminDeleteAdmin(token, admin.id);
      if (!mounted) return;
      setState(() => _admins.removeWhere((a) => a.id == admin.id));
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err is AuthError ? err.message : 'No se pudo eliminar al administrador')),
      );
    } finally {
      if (mounted) setState(() => _deleting.remove(admin.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.adminViolet,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Título y botón en una sola fila solo si caben; en el teléfono
              // el botón baja (antes partía "Administradores" a media palabra).
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.end,
                spacing: AppSpacing.lg,
                runSpacing: AppSpacing.md,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Administradores', style: AppTypography.h1),
                      const SizedBox(height: 4),
                      Text('Configuración y control de administradores.', style: AppTypography.body),
                    ],
                  ),
                  if (_canManage && !_showForm)
                    DsButton(
                      label: 'Añadir administrador',
                      icon: Icons.add,
                      variant: DsButtonVariant.primary,
                      accent: AppColors.adminViolet,
                      onPressed: () => setState(() => _showForm = true),
                    ),
                ],
              ),
              if (_canManage && _showForm) ...[
                const SizedBox(height: AppSpacing.xl),
                _buildForm(),
              ],
              const SizedBox(height: AppSpacing.xl),
              _buildList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return DsCard(
      background: AppColors.adminViolet.withValues(alpha: 0.05),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Nuevo administrador', style: AppTypography.h3),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Nombre',
              icon: Icons.person_outline,
              controller: _nameController,
              hintText: 'Nombre del administrador',
              accentColor: AppColors.adminViolet,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa un nombre' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Correo electrónico',
              icon: Icons.mail_outline,
              controller: _emailController,
              hintText: 'admin@touristmar.mx',
              keyboardType: TextInputType.emailAddress,
              accentColor: AppColors.adminViolet,
              validator: (v) => (v == null || !v.contains('@')) ? 'Ingresa un correo válido' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Contraseña temporal',
              icon: Icons.lock_outline,
              controller: _passwordController,
              obscureText: true,
              hintText: 'Mínimo 8 caracteres',
              accentColor: AppColors.adminViolet,
              validator: (v) => (v == null || v.length < 8) ? 'Mínimo 8 caracteres' : null,
            ),
            if (_formError != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(_formError!, style: TextStyle(color: AppColors.errorRed, fontSize: 13)),
            ],
            const SizedBox(height: AppSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                DsButton(
                  label: 'Cancelar',
                  variant: DsButtonVariant.ghost,
                  onPressed: _creating ? null : () => setState(() => _showForm = false),
                ),
                const SizedBox(width: AppSpacing.sm),
                DsButton(
                  label: _creating ? 'Creando...' : 'Crear administrador',
                  variant: DsButtonVariant.primary,
                  accent: AppColors.adminViolet,
                  onPressed: _creating ? null : _createAdmin,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_loading) return DsLoadingState();
    if (_error != null) return DsErrorState(message: _error!, onRetry: _load);
    if (_admins.isEmpty) {
      return const DsEmptyState(
        icon: Icons.shield_outlined,
        title: 'Sin administradores',
        subtitle: 'Aún no se ha registrado ningún administrador.',
      );
    }
    return Column(
      children: _admins
          .map((a) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _AdminRow(
                  admin: a,
                  canDelete: _canManage && !a.isSuperAdmin && a.id != widget.currentAdmin.id,
                  isDeleting: _deleting.contains(a.id),
                  onDelete: () => _deleteAdmin(a),
                ),
              ))
          .toList(),
    );
  }
}

class _AdminRow extends StatelessWidget {
  final AdminAccount admin;
  final bool canDelete;
  final bool isDeleting;
  final VoidCallback onDelete;

  const _AdminRow({required this.admin, required this.canDelete, required this.isDeleting, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return DsCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(admin.name, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                Text(admin.email, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.bodySmall),
              ],
            ),
          ),
          DsBadge(
            text: admin.isSuperAdmin ? 'Super Admin' : 'Administrador',
            tone: admin.isSuperAdmin ? BadgeTone.info : BadgeTone.neutral,
          ),
          if (canDelete) ...[
            const SizedBox(width: AppSpacing.sm),
            isDeleting
                ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.errorRed))
                : IconButton(
                    onPressed: onDelete,
                    icon: Icon(Icons.delete_outline, size: 18, color: AppColors.errorRed),
                  ),
          ],
        ],
      ),
    );
  }
}
