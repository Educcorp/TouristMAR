import 'package:flutter_test/flutter_test.dart';
import 'package:touristmar_web/services/ra_ubicacion.dart';

void main() {
  test('un lugar que es una de las playas recibe solo esa playa', () {
    expect(playaParaLugar('Playa La Audiencia'), 'Playa La Audiencia');
    expect(playaParaLugar('la audiencia'), 'Playa La Audiencia');
    expect(playaParaLugar('Playa Miramar'), 'Playa Miramar');
  });

  test('un lugar sin RA por ubicación no recibe otra playa', () {
    expect(playaParaLugar('Laguna de Cuyutlán'), isNull);
    expect(playaParaLugar('Cerro del Vigía'), isNull);
    expect(playaParaLugar('Hotel Las Brisas'), isNull);
    expect(playaParaLugar(''), isNull);
  });
}
