import 'package:flutter_test/flutter_test.dart';
import 'package:touristmar_web/utils/password_strength.dart';

/// Reglas para CREAR cuenta (lib/utils/password_strength.dart). Si cambian a
/// propósito, actualiza estas pruebas y `_contrasenaSegura` en
/// login_form_test.dart.
void main() {
  group('cumpleMinimo (lo que bloquea el registro)', () {
    test('una contraseña con 8+ caracteres, especial y no común cumple', () {
      expect(evaluatePasswordStrength('Faro#Manzanillo26').cumpleMinimo, isTrue);
      expect(evaluatePasswordStrength('kayak!mar').cumpleMinimo, isTrue);
    });

    test('menos de 8 caracteres no cumple', () {
      final r = evaluatePasswordStrength('Ab#1');
      expect(r.cumpleMinimo, isFalse);
      expect(r.pendientes, contains('Mínimo 8 caracteres'));
    });

    test('sin carácter especial no cumple', () {
      final r = evaluatePasswordStrength('Manzanillo2026');
      expect(r.cumpleMinimo, isFalse);
      expect(r.pendientes.first, 'Agrega un carácter especial (!@#\$...)');
    });

    test('las contraseñas comunes no cumplen, sin importar mayúsculas', () {
      for (final comun in ['password123', 'PASSWORD123', 'manzanillo', '12345678']) {
        expect(evaluatePasswordStrength(comun).cumpleMinimo, isFalse, reason: comun);
      }
    });

    test('números seguidos o repetidos no cumplen', () {
      expect(evaluatePasswordStrength('87654321').pendientes, contains('No uses números seguidos ni repetidos'));
      expect(evaluatePasswordStrength('aaaaaaaa').pendientes, contains('No uses números seguidos ni repetidos'));
    });
  });

  group('nivel de la barra', () {
    test('vacía y comunes son muy débiles', () {
      expect(evaluatePasswordStrength('').level, PasswordStrengthLevel.muyDebil);
      expect(evaluatePasswordStrength('password123').level, PasswordStrengthLevel.muyDebil);
    });

    test('larga, con mayúsculas, minúsculas, número y especial es fuerte', () {
      final r = evaluatePasswordStrength('Faro#Manzanillo26');
      expect(r.level, PasswordStrengthLevel.fuerte);
      expect(r.score, 1.0);
    });

    test('el puntaje siempre está entre 0 y 1', () {
      for (final p in ['', 'a', 'abcdefgh!', 'Faro#Manzanillo26', '11111111']) {
        final s = evaluatePasswordStrength(p).score;
        expect(s, inInclusiveRange(0.0, 1.0), reason: p);
      }
    });
  });
}
