import 'dart:convert';

/// Contrato de mensajes entre la app Flutter y el módulo AR de Unity
/// (Unity as a Library, vía `flutter_unity_widget`).
///
/// Es el espejo de `apps/ar-module/Assets/Scripts/Bridge/PuenteApp.cs` y
/// `ModelosMarcador.cs` — si cambias un nombre aquí, cámbialo allá también.
///
/// Uso típico en la pantalla de la cámara:
///
/// ```dart
/// UnityWidget(
///   onUnityCreated: (controller) {
///     final msg = ArBridge.configurar(apiBaseUrl: apiUrl, token: sesion?.token);
///     controller.postMessage(msg.gameObject, msg.method, msg.payload);
///   },
///   onUnityMessage: (raw) {
///     final evento = ArEvento.parse(raw.toString());
///     if (evento is ArMarcadorDetectado) {
///       // p. ej. mostrar evento.texto en un panel de la app
///     }
///   },
/// )
/// ```
class ArBridge {
  ArBridge._();

  /// Nombre del GameObject de la escena que recibe los mensajes.
  static const gameObject = 'PuenteApp';

  /// Arranca el módulo: le dice a Unity de dónde bajar los marcadores y, si el
  /// turista inició sesión, con qué token registrar sus escaneos.
  static ArMensaje configurar({required String apiBaseUrl, String? token}) {
    return ArMensaje(
      gameObject,
      'Configurar',
      jsonEncode({'apiBaseUrl': apiBaseUrl, 'token': token ?? ''}),
    );
  }

  /// Vuelve a pedir la lista de marcadores (p. ej. al regresar a la cámara).
  static ArMensaje recargar() => const ArMensaje(gameObject, 'Recargar', '');
}

class ArMensaje {
  final String gameObject;
  final String method;
  final String payload;

  const ArMensaje(this.gameObject, this.method, this.payload);
}

/// Eventos que Unity manda a Flutter (`EventoAR` en C#).
sealed class ArEvento {
  const ArEvento();

  static ArEvento parse(String raw) {
    final Map<String, dynamic> json;
    try {
      json = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return ArDesconocido(raw);
    }

    // JsonUtility serializa los strings vacíos como "", no como null.
    String? str(String key) {
      final v = json[key] as String?;
      return (v == null || v.isEmpty) ? null : v;
    }

    return switch (json['evento']) {
      'listo' => const ArListo(),
      'marcadoresCargados' => ArMarcadoresCargados((json['total'] as num?)?.toInt() ?? 0),
      'marcadorDetectado' => ArMarcadorDetectado(nombre: str('nombre') ?? '', texto: str('texto') ?? ''),
      'error' => ArError(str('mensaje') ?? 'Error desconocido en el módulo AR'),
      _ => ArDesconocido(raw),
    };
  }
}

/// Unity terminó de cargar la escena y ya puede recibir `configurar`.
class ArListo extends ArEvento {
  const ArListo();
}

class ArMarcadoresCargados extends ArEvento {
  final int total;
  const ArMarcadoresCargados(this.total);
}

/// Se manda una sola vez por marcador en cada sesión de cámara. [nombre] es
/// el identificador del marcador (ej. "gaviota_01") y [texto] su
/// `textoParaMostrar`, tal como vienen de GET /api/marcadores.
class ArMarcadorDetectado extends ArEvento {
  final String nombre;
  final String texto;
  const ArMarcadorDetectado({required this.nombre, required this.texto});
}

class ArError extends ArEvento {
  final String mensaje;
  const ArError(this.mensaje);
}

class ArDesconocido extends ArEvento {
  final String raw;
  const ArDesconocido(this.raw);
}
