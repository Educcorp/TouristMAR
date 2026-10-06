import 'package:flutter_test/flutter_test.dart';
import 'package:touristmar_web/widgets/mapa/ubicacion_lugar.dart';

void main() {
  group('parsearCoordenadas', () {
    test('lee las coordenadas tal como se copian de Google Maps', () {
      final c = parsearCoordenadas('19.12492145230218, -104.40020700589847')!;
      expect(c.lat, 19.12492145230218);
      expect(c.lng, -104.40020700589847);
    });

    test('acepta los dos números separados por espacio', () {
      expect(parsearCoordenadas('19.1249 -104.4002')!.lng, -104.4002);
    });

    test('rechaza texto incompleto o fuera de rango', () {
      expect(parsearCoordenadas('19.1249'), isNull);
      expect(parsearCoordenadas('120, -104'), isNull);
      expect(parsearCoordenadas(''), isNull);
    });
  });
}
