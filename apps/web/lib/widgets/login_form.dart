import 'dart:html' as html;

import 'package:flutter/material.dart';

import '../pages/home_page.dart';
import '../services/auth_service.dart';
import '../services/session_storage.dart';
import '../theme/app_theme.dart';
import '../theme/breakpoints.dart';
import 'app_button.dart';
import 'app_text_field.dart';
import 'google_logo.dart';
import 'register_place_banner.dart';

enum _Mode { login, register }

class LoginForm extends StatefulWidget {
  final AuthService authService;

  LoginForm({super.key, AuthService? authService}) : authService = authService ?? AuthService();

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  _Mode _mode = _Mode.login;
  bool _showPassword = false;
  bool _isSubmitting = false;
  bool _isRestoringSession = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _restoreSession() async {
    final uri = Uri.base;
    final tokenFromRedirect = uri.queryParameters['token'];
    final googleError = uri.queryParameters['error'];

    if (tokenFromRedirect != null || googleError != null) {
      html.window.history.replaceState(null, '', uri.path);
    }

    if (googleError != null) {
      setState(() => _error = 'No se pudo iniciar sesión con Google');
    }

    final token = tokenFromRedirect ?? SessionStorage.token;

    if (token == null) {
      setState(() => _isRestoringSession = false);
      return;
    }

    try {
      final restoredUser = await widget.authService.getCurrentUser(token);
      SessionStorage.saveToken(token);
      if (!mounted) return;
      _goToHome(restoredUser);
    } catch (_) {
      SessionStorage.clearToken();
    } finally {
      if (mounted) setState(() => _isRestoringSession = false);
    }
  }

  void _goToHome(AuthUser user) {
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => HomePage(user: user)));
  }

  Future<void> _handleSubmit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _error = null;
      _isSubmitting = true;
    });

    try {
      final response = _mode == _Mode.login
          ? await widget.authService.login(_emailController.text, _passwordController.text)
          : await widget.authService.register(
              _emailController.text,
              _passwordController.text,
              _nameController.text,
            );
      SessionStorage.saveToken(response.token);
      _goToHome(response.user);
    } catch (err) {
      setState(() {
        _error = err is AuthError ? err.message : 'No se pudo conectar con el servidor';
      });
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _toggleMode() {
    setState(() {
      _error = null;
      _mode = _mode == _Mode.login ? _Mode.register : _Mode.login;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isRestoringSession) {
      return const SizedBox.expand();
    }

    return _buildForm();
  }

  Widget _buildForm() {
    final isNarrow = !Breakpoints.isExpanded(MediaQuery.sizeOf(context).width);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isNarrow) ...[
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(color: AppColors.brandTeal, shape: BoxShape.circle),
                        child: const Icon(Icons.waves, size: 20, color: AppColors.panelNavy),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'TOURISMAR',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, letterSpacing: 3),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
                Text(
                  _mode == _Mode.login ? 'Bienvenido de vuelta' : 'Crea tu cuenta',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  _mode == _Mode.login
                      ? 'Inicia sesión para seguir explorando Manzanillo'
                      : 'Regístrate para guardar tus lugares favoritos',
                  style: const TextStyle(color: AppColors.slate400, fontSize: 14),
                ),
                const SizedBox(height: 24),
                if (_mode == _Mode.register) ...[
                  AppTextField(
                    fieldKey: const ValueKey('name-field'),
                    label: 'Nombre',
                    icon: Icons.person_outline,
                    controller: _nameController,
                    hintText: 'Tu nombre',
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa tu nombre' : null,
                  ),
                  const SizedBox(height: 20),
                ],
                AppTextField(
                  fieldKey: const ValueKey('email-field'),
                  label: 'Correo electrónico',
                  icon: Icons.mail_outline,
                  controller: _emailController,
                  hintText: 'tu@correo.com',
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => (v == null || !v.contains('@')) ? 'Ingresa un correo válido' : null,
                ),
                const SizedBox(height: 20),
                AppTextField(
                  fieldKey: const ValueKey('password-field'),
                  label: 'Contraseña',
                  icon: Icons.lock_outline,
                  controller: _passwordController,
                  obscureText: !_showPassword,
                  hintText: '••••••••',
                  validator: (v) => (v == null || v.length < 8) ? 'Mínimo 8 caracteres' : null,
                  suffixIcon: IconButton(
                    icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility, color: AppColors.slate500),
                    onPressed: () => setState(() => _showPassword = !_showPassword),
                  ),
                ),
                if (_mode == _Mode.login) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {},
                      child: const Text(
                        '¿Olvidaste tu contraseña?',
                        style: TextStyle(color: AppColors.brandTeal, fontSize: 12),
                      ),
                    ),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: AppColors.errorRed, fontSize: 14)),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.white.withOpacity(0.1))),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('o continúa con Google', style: TextStyle(color: AppColors.slate500, fontSize: 12)),
                    ),
                    Expanded(child: Divider(color: Colors.white.withOpacity(0.1))),
                  ],
                ),
                const SizedBox(height: 20),
                AppButton(
                  variant: AppButtonVariant.google,
                  onPressed: () => html.window.location.href = widget.authService.googleLoginUrl,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GoogleLogo(),
                      SizedBox(width: 8),
                      Text('Continuar con Google'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                AppButton(
                  variant: AppButtonVariant.primary,
                  onPressed: _isSubmitting ? null : _handleSubmit,
                  child: Text(
                    _isSubmitting
                        ? (_mode == _Mode.login ? 'Iniciando sesión...' : 'Creando cuenta...')
                        : (_mode == _Mode.login ? 'Iniciar sesión' : 'Crear cuenta'),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    children: [
                      Text(
                        _mode == _Mode.login ? '¿No tienes cuenta? ' : '¿Ya tienes cuenta? ',
                        style: const TextStyle(color: AppColors.slate400, fontSize: 14),
                      ),
                      GestureDetector(
                        onTap: _toggleMode,
                        child: Text(
                          _mode == _Mode.login ? 'Regístrate gratis' : 'Inicia sesión',
                          style: const TextStyle(color: AppColors.brandTeal, fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                RegisterPlaceBanner(onTap: () {}),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
