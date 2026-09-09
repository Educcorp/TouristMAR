/// Anchos de referencia usados para decidir cuándo una vista pasa a su
/// distribución angosta (la misma que va a usar la app móvil). Centralizarlos
/// aquí evita numeritos sueltos repetidos en cada pantalla y deja explícito
/// qué contenido ya está pensado para el ancho de un teléfono.
class Breakpoints {
  Breakpoints._();

  /// Por debajo de esto, una pantalla se ve prácticamente igual que en móvil.
  static const compact = 700.0;

  /// Punto en el que dejan de caber columnas/paneles lado a lado.
  static const expanded = 1024.0;

  static bool isCompact(double width) => width < compact;

  static bool isExpanded(double width) => width >= expanded;
}
