import 'imprimir_marcador_stub.dart' if (dart.library.js_interop) 'imprimir_marcador_web.dart' as plataforma;

/// Si esta plataforma puede mandar el marcador a la impresora (solo la web:
/// el diálogo de impresión del navegador).
bool get puedeImprimirMarcador => plataforma.puedeImprimir;

/// Abre una hoja limpia (solo el marcador y el nombre del lugar) y el
/// diálogo de impresión del navegador. Devuelve `false` si no se pudo abrir
/// (p. ej. el navegador bloqueó la ventana emergente).
bool imprimirMarcador({required String imagenUrl, required String lugar, String? titulo}) =>
    plataforma.imprimir(imagenUrl: imagenUrl, lugar: lugar, titulo: titulo);
