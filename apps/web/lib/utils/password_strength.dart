/// Reglas de contraseña para crear cuenta (visitante y empresa comparten el
/// mismo formulario de registro). El backend solo exige 8 caracteres
/// (`auth.controller.ts`); esto es una capa extra solo en el frontend — por
/// eso el login (no el registro) sigue aceptando contraseñas viejas que no
/// cumplan estas reglas más estrictas.
library;

enum PasswordStrengthLevel { muyDebil, debil, media, fuerte }

class PasswordStrengthResult {
  final PasswordStrengthLevel level;
  final double score;
  final List<String> pendientes;

  const PasswordStrengthResult({required this.level, required this.score, required this.pendientes});

  bool get cumpleMinimo => pendientes.isEmpty;
}

const _comunes = {
  '12345678', '123456789', '1234567890', 'password', 'password1', 'password123',
  'contraseña', 'contrasena', 'contrasena1', 'qwerty123', 'qwertyui', 'abcdefgh',
  '11111111', '00000000', 'admin123', 'iloveyou', 'manzanillo',
};

final _especial = RegExp(r'''[!@#$%^&*(),.?":{}|<>_\-+=/\\\[\]~`]''');
final _mayuscula = RegExp(r'[A-ZÁÉÍÓÚÑ]');
final _minuscula = RegExp(r'[a-záéíóúñ]');
final _numero = RegExp(r'\d');
final _soloDigitos = RegExp(r'^\d+$');

bool _esSecuenciaORepeticion(String s) {
  if (s.isEmpty) return false;
  if (s.split('').toSet().length == 1) return true; // "aaaaaaaa", "11111111"
  if (_soloDigitos.hasMatch(s) && s.length >= 4) {
    var ascendente = true;
    var descendente = true;
    for (var i = 1; i < s.length; i++) {
      final diff = s.codeUnitAt(i) - s.codeUnitAt(i - 1);
      if (diff != 1) ascendente = false;
      if (diff != -1) descendente = false;
    }
    if (ascendente || descendente) return true; // "12345678", "87654321"
  }
  return false;
}

PasswordStrengthResult evaluatePasswordStrength(String password) {
  final esComun = _comunes.contains(password.toLowerCase());
  final esSecuencia = _esSecuenciaORepeticion(password);

  final pendientes = <String>[];
  if (password.length < 8) pendientes.add('Mínimo 8 caracteres');
  if (!_especial.hasMatch(password)) pendientes.add('Agrega un carácter especial (!@#\$...)');
  if (esSecuencia) pendientes.add('No uses números seguidos ni repetidos');
  if (esComun) pendientes.add('Esa contraseña es muy común, elige otra');

  var puntos = 0;
  if (password.length >= 8) puntos++;
  if (password.length >= 12) puntos++;
  if (_mayuscula.hasMatch(password) && _minuscula.hasMatch(password)) puntos++;
  if (_numero.hasMatch(password)) puntos++;
  if (_especial.hasMatch(password)) puntos++;
  if (esSecuencia || esComun) puntos = 0;

  final PasswordStrengthLevel level;
  if (password.isEmpty || puntos <= 1) {
    level = PasswordStrengthLevel.muyDebil;
  } else if (puntos == 2) {
    level = PasswordStrengthLevel.debil;
  } else if (puntos <= 4) {
    level = PasswordStrengthLevel.media;
  } else {
    level = PasswordStrengthLevel.fuerte;
  }

  return PasswordStrengthResult(
    level: level,
    score: password.isEmpty ? 0.0 : (puntos / 5).clamp(0.0, 1.0),
    pendientes: pendientes,
  );
}
