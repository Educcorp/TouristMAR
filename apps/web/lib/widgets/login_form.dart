import 'dart:html' as html;

import 'package:flutter/material.dart';

import '../pages/admin/admin_dashboard_page.dart';
import '../pages/business_home_page.dart';
import '../pages/home_page.dart';
import '../services/auth_service.dart';
import '../services/session_storage.dart';
import '../theme/app_theme.dart';
import '../theme/breakpoints.dart';
import 'app_button.dart';
import 'app_text_field.dart';
import 'google_logo.dart';
import 'register_place_banner.dart';
import 'session_guard.dart';
import 'app_logo.dart';

enum _Mode { login, register }

enum _LoginType { visitor, business }

enum _Screen { credentials, forgot, forgotSent, negocioEstado }

class LoginForm extends StatefulWidget {
  final AuthService authService;
  final String? initialError;

  LoginForm({super.key, AuthService? authService, this.initialError}) : authService = authService ?? AuthService();

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
  NegocioInfo? _negocioEstado;

  bool get _isBusiness => _loginType == _LoginType.business;

  @override
  void initState() {
    super.initState();
    _error = widget.initialError;
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
    final googleMessage = uri.queryParameters['message'];

    if (tokenFromRedirect != null || googleError != null) {
      html.window.history.replaceState(null, '', uri.path);
    }

    if (googleError != null) {
      setState(() => _error = googleMessage ?? 'No se pudo iniciar sesión con Google');
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
      _routeUser(restoredUser);
      // No hacer más `setState` después de navegar: `pushReplacement` anima
      // la transición y no desmonta esta pantalla al instante. Si acá se
      // reactivara `_isRestoringSession` a false, este LoginForm se
      // reconstruiría visible (mostrando el formulario completo) justo
      // debajo de la ruta nueva mientras esta última termina de entrar —
      // el parpadeo de vuelta al login antes de llegar al perfil.
      return;
    } catch (_) {
      SessionStorage.clearToken();
    }
    if (mounted) setState(() => _isRestoringSession = false);
  }

  /// Decide a dónde mandar al usuario según su rol y, si es negocio, su
  /// estado de aprobación. Un negocio pendiente/rechazado nunca llega al
  /// panel — se queda en esta misma pantalla mostrando su estado.
  void _routeUser(AuthUser user) {
    if (user.isAdmin) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => SessionGuard(child: AdminDashboardPage(admin: user))),
      );
      return;
    }
    if (user.isNegocio) {
      if (user.negociosAprobados.isNotEmpty) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => SessionGuard(child: BusinessHomePage(user: user))),
        );
        return;
      }
      setState(() {
        _negocioEstado = user.negocios.isNotEmpty ? user.negocios.first : null;
        _screen = _Screen.negocioEstado;
      });
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => SessionGuard(child: HomePage(user: user))),
    );
  }

  void _handleGoogleOrBusinessClick() {
    html.window.location.href = widget.authService.googleLoginUrl;
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
              rol: _isBusiness ? 'negocio' : 'turista',
              categoria: _isBusiness ? _categoryController.text : null,
            );
      SessionStorage.saveToken(response.token);
      _routeUser(response.user);
      // Igual que en `_restoreSession`: no tocar el estado de este formulario
      // después de navegar, para no reconstruirlo (con el botón vuelto a su
      // texto normal) mientras la transición de `pushReplacement` todavía lo
      // tiene visible debajo de la ruta nueva.
      return;
    } catch (err) {
      setState(() {
        _error = err is AuthError ? err.message : 'No se pudo conectar con el servidor';
      });
    }
    if (mounted) setState(() => _isSubmitting = false);
  }

  void _logout() {
    SessionStorage.clearToken();
    setState(() {
      _negocioEstado = null;
      _screen = _Screen.credentials;
      _mode = _Mode.login;
    });
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
      case _Screen.negocioEstado:
        return _buildNegocioEstado();
      case _Screen.credentials:
        return _buildForm();
    }
  }

  Widget _buildNegocioEstado() {
    final isNarrow = !Breakpoints.isExpanded(MediaQuery.sizeOf(context).width);
    final rechazado = _negocioEstado?.rechazado ?? false;
    final icon = rechazado ? Icons.cancel_outlined : Icons.hourglass_top_outlined;
    final color = rechazado ? AppColors.errorRed : AppColors.businessOrange;
    final title = rechazado ? 'Registro no aprobado' : 'Tu negocio está en revisión';
    final message = rechazado
        ? 'Un administrador de TouristMAR revisó tu solicitud y no fue aprobada. Si crees que es un error, contáctanos.'
        : 'Un administrador de TouristMAR todavía tiene que revisar y aprobar tu cuenta antes de que puedas acceder a tu panel de negocio.';

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isNarrow) ...[
                Center(child: _buildLogo()),
                const SizedBox(height: 32),
              ],
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: color.withOpacity(0.25)),
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
              ),
              const SizedBox(height: 24),
              Text(title, style: Theme.of(context).textTheme.headlineMedium, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.slate400, fontSize: 14, height: 1.4),
              ),
              if (_negocioEstado != null) ...[
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.overlay(0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.overlay(0.1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_negocioEstado!.nombre,
                          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                      if (_negocioEstado!.categoria != null)
                        Text(_negocioEstado!.categoria!, style: TextStyle(color: AppColors.slate400, fontSize: 12)),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 28),
              AppButton(variant: AppButtonVariant.ghost, onPressed: _logout, child: const Text('Cerrar sesión')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppLogo(size: 36),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            'TOURISTMAR',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, letterSpacing: 3),
          ),
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
        border: Border.all(color: AppColors.overlay(0.08)),
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
                          ? 'Comienza a gestionar tu lugar en TouristMAR'
                          : 'Regístrate para guardar tus lugares favoritos')
                      : (_isBusiness
                          ? 'Gestiona tu negocio o lugar turístico'
                          : 'Inicia sesión para seguir explorando Manzanillo'),
                  style: TextStyle(color: AppColors.slate400, fontSize: 14),
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
                      child: Text(
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
                      color: AppColors.overlay(0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.overlay(0.1)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, size: 15, color: accentColor),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Tu registro será revisado por un administrador de TouristMAR antes de aparecer en el mapa.',
                            style: TextStyle(color: AppColors.slate400, fontSize: 12, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(color: AppColors.errorRed, fontSize: 14)),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: Divider(color: AppColors.overlay(0.1))),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('o continúa con Google', style: TextStyle(color: AppColors.slate500, fontSize: 12)),
                    ),
                    Expanded(child: Divider(color: AppColors.overlay(0.1))),
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
                        style: TextStyle(color: AppColors.slate400, fontSize: 14),
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
                  icon: Icon(Icons.arrow_back, size: 15, color: AppColors.slate400),
                  label: Text('Volver', style: TextStyle(color: AppColors.slate400, fontSize: 13)),
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
                child: Icon(Icons.mail_outline, color: AppColors.brandTeal, size: 22),
              ),
              const SizedBox(height: 20),
              Text('Recupera tu acceso', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 6),
              Text(
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
                child: Icon(Icons.mail_outline, color: AppColors.brandTeal, size: 28),
              ),
              const SizedBox(height: 24),
              Text('Revisa tu correo', style: Theme.of(context).textTheme.headlineMedium, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Text.rich(
                TextSpan(
                  style: TextStyle(color: AppColors.slate400, fontSize: 14, height: 1.4),
                  children: [
                    const TextSpan(text: 'Si existe una cuenta con '),
                    TextSpan(
                      text: email.isEmpty ? 'ese correo' : email,
                      style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                    ),
                    const TextSpan(text: ', recibirás un enlace en los próximos minutos.'),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              GestureDetector(
                onTap: () => setState(() => _screen = _Screen.credentials),
                child: Text(
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
