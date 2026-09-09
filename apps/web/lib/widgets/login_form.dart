import 'dart:html' as html;

import 'package:flutter/material.dart';

import '../models/business_profile.dart';
import '../pages/business_dashboard_page.dart';
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

enum _LoginType { visitor, business }

enum _Screen { credentials, forgot, forgotSent }

class LoginForm extends StatefulWidget {
  final AuthService authService;

  LoginForm({super.key, AuthService? authService}) : authService = authService ?? AuthService();

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _categoryController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  _Mode _mode = _Mode.login;
  _LoginType _loginType = _LoginType.visitor;
  _Screen _screen = _Screen.credentials;
  bool _showPassword = false;
  bool _isSubmitting = false;
  bool _isRestoringSession = true;
  String? _error;

  bool get _isBusiness => _loginType == _LoginType.business;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
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

  void _goToBusinessDashboard(BusinessProfile business) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => BusinessDashboardPage(business: business)),
    );
  }

  void _handleGoogleOrBusinessClick() {
    if (_isBusiness) {
      _goToBusinessDashboard(BusinessProfile.mock());
      return;
    }
    html.window.location.href = widget.authService.googleLoginUrl;
  }

  Future<void> _handleSubmit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_isBusiness) {
      _goToBusinessDashboard(
        BusinessProfile.mock(
          businessName: _mode == _Mode.register ? _nameController.text : null,
          email: _mode == _Mode.register ? _emailController.text : null,
          category: _mode == _Mode.register ? _categoryController.text : null,
        ),
      );
      return;
    }

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

  void _setLoginType(_LoginType type) {
    setState(() {
      _error = null;
      _loginType = type;
    });
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

    switch (_screen) {
      case _Screen.forgot:
        return _buildForgot();
      case _Screen.forgotSent:
        return _buildForgotSent();
      case _Screen.credentials:
        return _buildForm();
    }
  }

  Widget _buildLogo() {
    return Row(
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
    );
  }

  Widget _buildTypeToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.panelNavySoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: _LoginType.values.map((type) {
          final active = _loginType == type;
          final isBusinessTab = type == _LoginType.business;
          final activeColor = isBusinessTab ? AppColors.businessOrange : AppColors.brandTeal;
          final foreground = active ? (isBusinessTab ? Colors.white : AppColors.panelNavy) : AppColors.slate400;

          return Expanded(
            child: GestureDetector(
              onTap: () => _setLoginType(type),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: active ? activeColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(isBusinessTab ? Icons.apartment : Icons.person_outline, size: 15, color: foreground),
                    const SizedBox(width: 6),
                    Text(
                      isBusinessTab ? 'Empresa' : 'Visitante',
                      style: TextStyle(color: foreground, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildForm() {
    final isNarrow = !Breakpoints.isExpanded(MediaQuery.sizeOf(context).width);
    final accentColor = _isBusiness ? AppColors.businessOrange : AppColors.brandTeal;
    final isRegister = _mode == _Mode.register;

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
                  _buildLogo(),
                  const SizedBox(height: 24),
                ],
                _buildTypeToggle(),
                const SizedBox(height: 24),
                Text(
                  isRegister
                      ? (_isBusiness ? 'Registra tu negocio' : 'Crea tu cuenta')
                      : (_isBusiness ? 'Accede a tu panel' : 'Bienvenido de vuelta'),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  isRegister
                      ? (_isBusiness
                          ? 'Comienza a gestionar tu lugar en TourisMAR'
                          : 'Regístrate para guardar tus lugares favoritos')
                      : (_isBusiness
                          ? 'Gestiona tu negocio o lugar turístico'
                          : 'Inicia sesión para seguir explorando Manzanillo'),
                  style: const TextStyle(color: AppColors.slate400, fontSize: 14),
                ),
                const SizedBox(height: 24),
                if (isRegister) ...[
                  AppTextField(
                    fieldKey: const ValueKey('name-field'),
                    label: _isBusiness ? 'Nombre del negocio' : 'Nombre',
                    icon: _isBusiness ? Icons.apartment : Icons.person_outline,
                    controller: _nameController,
                    hintText: _isBusiness ? 'Playa Audiencia Resort' : 'Tu nombre',
                    accentColor: accentColor,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? (_isBusiness ? 'Ingresa el nombre del negocio' : 'Ingresa tu nombre')
                        : null,
                  ),
                  const SizedBox(height: 20),
                  if (_isBusiness) ...[
                    AppTextField(
                      fieldKey: const ValueKey('category-field'),
                      label: 'Categoría',
                      icon: Icons.local_offer_outlined,
                      controller: _categoryController,
                      hintText: 'Ej. Playa · Restaurante · Mirador',
                      accentColor: accentColor,
                    ),
                    const SizedBox(height: 20),
                  ],
                ],
                AppTextField(
                  fieldKey: const ValueKey('email-field'),
                  label: 'Correo electrónico',
                  icon: Icons.mail_outline,
                  controller: _emailController,
                  hintText: _isBusiness ? 'contacto@minegocio.mx' : 'tu@correo.com',
                  keyboardType: TextInputType.emailAddress,
                  accentColor: accentColor,
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
                  accentColor: accentColor,
                  validator: (v) => (v == null || v.length < 8) ? 'Mínimo 8 caracteres' : null,
                  suffixIcon: IconButton(
                    icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility, color: AppColors.slate500),
                    onPressed: () => setState(() => _showPassword = !_showPassword),
                  ),
                ),
                if (!isRegister) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => setState(() => _screen = _Screen.forgot),
                      child: const Text(
                        '¿Olvidaste tu contraseña?',
                        style: TextStyle(color: AppColors.brandTeal, fontSize: 12),
                      ),
                    ),
                  ),
                ],
                if (isRegister && _isBusiness) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, size: 15, color: accentColor),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Tu registro será revisado por un administrador de TourisMAR antes de aparecer en el mapa.',
                            style: TextStyle(color: AppColors.slate400, fontSize: 12, height: 1.4),
                          ),
                        ),
                      ],
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
                  onPressed: _handleGoogleOrBusinessClick,
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
                  backgroundColor: _isBusiness ? AppColors.businessOrange : null,
                  foregroundColor: _isBusiness ? Colors.white : null,
                  onPressed: _isSubmitting ? null : _handleSubmit,
                  child: Text(
                    _isSubmitting
                        ? (isRegister ? 'Creando cuenta...' : 'Iniciando sesión...')
                        : (isRegister
                            ? (_isBusiness ? 'Solicitar registro' : 'Crear cuenta')
                            : (_isBusiness ? 'Acceder al panel' : 'Iniciar sesión')),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    children: [
                      Text(
                        isRegister ? '¿Ya tienes cuenta? ' : '¿No tienes cuenta? ',
                        style: const TextStyle(color: AppColors.slate400, fontSize: 14),
                      ),
                      GestureDetector(
                        onTap: _toggleMode,
                        child: Text(
                          isRegister
                              ? 'Inicia sesión'
                              : (_isBusiness ? 'Registra tu negocio' : 'Regístrate gratis'),
                          style: TextStyle(color: accentColor, fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!_isBusiness) ...[
                  const SizedBox(height: 24),
                  RegisterPlaceBanner(onTap: () {}),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForgot() {
    final isNarrow = !Breakpoints.isExpanded(MediaQuery.sizeOf(context).width);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isNarrow) ...[
                _buildLogo(),
                const SizedBox(height: 24),
              ],
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() => _screen = _Screen.credentials),
                  icon: const Icon(Icons.arrow_back, size: 15, color: AppColors.slate400),
                  label: const Text('Volver', style: TextStyle(color: AppColors.slate400, fontSize: 13)),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.brandTeal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.brandTeal.withOpacity(0.2)),
                ),
                child: const Icon(Icons.mail_outline, color: AppColors.brandTeal, size: 22),
              ),
              const SizedBox(height: 20),
              Text('Recupera tu acceso', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 6),
              const Text(
                'Ingresa tu correo y te enviaremos un enlace para restablecer tu contraseña.',
                style: TextStyle(color: AppColors.slate400, fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 24),
              AppTextField(
                label: 'Correo electrónico',
                icon: Icons.mail_outline,
                controller: _emailController,
                hintText: 'tu@correo.com',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 20),
              AppButton(
                onPressed: () => setState(() => _screen = _Screen.forgotSent),
                child: const Text('Enviar enlace de recuperación'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForgotSent() {
    final isNarrow = !Breakpoints.isExpanded(MediaQuery.sizeOf(context).width);
    final email = _emailController.text.trim();

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (isNarrow) ...[
                _buildLogo(),
                const SizedBox(height: 32),
              ],
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.brandTeal.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.brandTeal.withOpacity(0.25)),
                ),
                child: const Icon(Icons.mail_outline, color: AppColors.brandTeal, size: 28),
              ),
              const SizedBox(height: 24),
              Text('Revisa tu correo', style: Theme.of(context).textTheme.headlineMedium, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Text.rich(
                TextSpan(
                  style: const TextStyle(color: AppColors.slate400, fontSize: 14, height: 1.4),
                  children: [
                    const TextSpan(text: 'Si existe una cuenta con '),
                    TextSpan(
                      text: email.isEmpty ? 'ese correo' : email,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                    const TextSpan(text: ', recibirás un enlace en los próximos minutos.'),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              GestureDetector(
                onTap: () => setState(() => _screen = _Screen.credentials),
                child: const Text(
                  'Volver al inicio de sesión',
                  style: TextStyle(color: AppColors.brandTeal, fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
