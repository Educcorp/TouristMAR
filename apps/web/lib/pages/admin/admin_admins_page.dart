import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/session_storage.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';

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
    return Scaffold(
      backgroundColor: AppColors.panelNavy,
      appBar: AppBar(
        backgroundColor: AppColors.panelNavy,
        foregroundColor: Colors.white,
        title: const Text('Administradores'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                if (_canManage) ...[
                  if (!_showForm)
                    AppButton(
                      backgroundColor: AppColors.adminViolet.withOpacity(0.15),
                      foregroundColor: AppColors.adminViolet,
                      onPressed: () => setState(() => _showForm = true),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [Icon(Icons.add, size: 16), SizedBox(width: 6), Text('Añadir administrador')],
                      ),
                    )
                  else
                    _buildForm(),
                  const SizedBox(height: 20),
                ],
                _buildList(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.adminViolet.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.adminViolet.withOpacity(0.2)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('NUEVO ADMINISTRADOR', style: TextStyle(color: AppColors.adminViolet, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
            const SizedBox(height: 14),
            AppTextField(
              label: 'Nombre',
              icon: Icons.person_outline,
              controller: _nameController,
              hintText: 'Nombre del administrador',
              accentColor: AppColors.adminViolet,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa un nombre' : null,
            ),
            const SizedBox(height: 14),
            AppTextField(
              label: 'Correo electrónico',
              icon: Icons.mail_outline,
              controller: _emailController,
              hintText: 'admin@tourismar.mx',
              keyboardType: TextInputType.emailAddress,
              accentColor: AppColors.adminViolet,
              validator: (v) => (v == null || !v.contains('@')) ? 'Ingresa un correo válido' : null,
            ),
            const SizedBox(height: 14),
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
              const SizedBox(height: 10),
              Text(_formError!, style: const TextStyle(color: AppColors.errorRed, fontSize: 13)),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    variant: AppButtonVariant.ghost,
                    onPressed: _creating ? null : () => setState(() => _showForm = false),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppButton(
                    backgroundColor: AppColors.adminViolet,
                    foregroundColor: Colors.white,
                    onPressed: _creating ? null : _createAdmin,
                    child: Text(_creating ? 'Creando...' : 'Crear administrador'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator(color: AppColors.adminViolet)),
      );
    }
    if (_error != null) {
      return Center(child: Text(_error!, style: const TextStyle(color: AppColors.errorRed)));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _admins
          .map((a) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _AdminTile(
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

class _AdminTile extends StatelessWidget {
  final AdminAccount admin;
  final bool canDelete;
  final bool isDeleting;
  final VoidCallback onDelete;

  const _AdminTile({required this.admin, required this.canDelete, required this.isDeleting, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(admin.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                Text(admin.email, style: const TextStyle(color: AppColors.slate400, fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: (admin.isSuperAdmin ? AppColors.adminViolet : AppColors.brandTeal).withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: (admin.isSuperAdmin ? AppColors.adminViolet : AppColors.brandTeal).withOpacity(0.3)),
            ),
            child: Text(
              admin.isSuperAdmin ? 'Super Admin' : 'Administrador',
              style: TextStyle(color: admin.isSuperAdmin ? AppColors.adminViolet : AppColors.brandTeal, fontSize: 10, fontWeight: FontWeight.w700),
            ),
          ),
          if (canDelete) ...[
            const SizedBox(width: 8),
            isDeleting
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.errorRed))
                : IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.errorRed),
                  ),
          ],
        ],
      ),
    );
  }
}
