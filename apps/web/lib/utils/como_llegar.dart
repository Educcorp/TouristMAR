import 'package:url_launcher/url_launcher.dart';

import '../models/lugar.dart';

/// Abre la ruta hacia el lugar en Google Maps (la app en el teléfono, una
/// pestaña nueva en la web). El origen lo pone Google con la ubicación del
/// visitante.
Future<bool> abrirComoLlegar(Coordenadas destino) {
  final uri = Uri.https('www.google.com', '/maps/dir/', {
    'api': '1',
    'destination': '${destino.lat},${destino.lng}',
  });
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}
