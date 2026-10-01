import 'package:flutter/widgets.dart';

/// Quita el foco del campo de texto activo y, con eso, cierra el teclado.
///
/// En Android cerrar el teclado con el botón "atrás" NO le quita el foco al
/// campo (p. ej. la barra de búsqueda del inicio). Después, al abrir el
/// sidebar o el diálogo de notificaciones y volver, Flutter le regresa el foco
/// a ese campo y el teclado se vuelve a desplegar solo. Llamar a esto antes de
/// abrir/cerrar esos paneles evita que el teclado aparezca sin que el usuario
/// lo pida.
void hideKeyboard() => FocusManager.instance.primaryFocus?.unfocus();
