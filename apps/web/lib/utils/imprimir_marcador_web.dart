import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

const bool puedeImprimir = true;

String _escapar(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

/// Se imprime desde una ventana con HTML simple (no la página de Flutter):
/// el lienzo de Flutter no se imprime bien y así la hoja sale solo con el
/// marcador, centrado y a tamaño completo.
bool imprimir({required String imagenUrl, required String lugar, String? titulo}) {
  final ventana = web.window.open('', '_blank');
  if (ventana == null) return false;
  final subtitulo = titulo == null || titulo.trim().isEmpty || titulo.trim() == lugar.trim()
      ? ''
      : '<p>${_escapar(titulo.trim())}</p>';
  final html = '''<!doctype html>
<html lang="es"><head><meta charset="utf-8"><title>Marcador · ${_escapar(lugar)}</title>
<style>
  @page { size: auto; margin: 12mm; }
  * { box-sizing: border-box; }
  html, body { margin: 0; height: 100%; background: #fff; color: #0b2a3a;
    font-family: system-ui, -apple-system, "Segoe UI", Roboto, sans-serif; }
  main { min-height: 100%; display: flex; flex-direction: column; align-items: center;
    justify-content: center; gap: 8mm; padding: 8mm; text-align: center; }
  h1 { margin: 0; font-size: 26pt; line-height: 1.15; }
  p { margin: 0; font-size: 13pt; color: #4a5a63; }
  img { display: block; max-width: 100%; max-height: 72vh; object-fit: contain;
    image-rendering: auto; }
</style></head>
<body><main>
  <h1>${_escapar(lugar)}</h1>
  $subtitulo
  <img src="${_escapar(imagenUrl)}" alt="Marcador de realidad aumentada"
       onload="setTimeout(function(){ window.focus(); window.print(); }, 150)">
</main></body></html>''';
  final doc = ventana.document as JSObject;
  doc.callMethod<JSAny?>('open'.toJS);
  doc.callMethod<JSAny?>('write'.toJS, html.toJS);
  doc.callMethod<JSAny?>('close'.toJS);
  return true;
}
