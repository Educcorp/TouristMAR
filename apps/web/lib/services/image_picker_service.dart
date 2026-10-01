import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// Imagen elegida por el usuario, todavía en memoria (sin subir).
class PickedImage {
  final Uint8List bytes;
  final String name;

  const PickedImage(this.bytes, this.name);
}

/// Punto único para elegir una imagen del dispositivo.
///
/// Las pantallas de edición (perfil, portada y galería del negocio) lo usan en
/// vez de llamar a `FilePicker` directo, para que las pruebas automáticas
/// puedan simular "el usuario eligió una foto" sin abrir el selector real del
/// sistema (ver `test/correcciones_errores_test.dart`).
class ImagePickerService {
  ImagePickerService._();

  /// Se puede reemplazar en pruebas. Devuelve `null` si el usuario cancela.
  static Future<PickedImage?> Function() pick = _pickWithFilePicker;

  static Future<PickedImage?> _pickWithFilePicker() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    final file = result?.files.single;
    if (file == null || file.bytes == null) return null;
    return PickedImage(file.bytes!, file.name);
  }
}
