const _monthsEs = [
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sep',
  'oct',
  'nov',
  'dic',
];

const _monthsEsFull = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

/// Formatea una fecha como "13 sep. 2026" sin depender del paquete `intl`
/// (evita agregar una dependencia nueva y la inicialización de locale que
/// requeriría `DateFormat` con `es`).
String formatDateEs(DateTime date) {
  return '${date.day} ${_monthsEs[date.month - 1]}. ${date.year}';
}

/// Formato largo: "13 de septiembre de 2026".
String formatDateEsLong(DateTime date) {
  return '${date.day} de ${_monthsEsFull[date.month - 1]} de ${date.year}';
}

/// Etiqueta corta de mes+año para agrupar series, p. ej. "sep. 2026".
String monthLabelEs(DateTime date) => '${_monthsEs[date.month - 1]}. ${date.year}';
