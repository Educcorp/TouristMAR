/// Horario semanal de un negocio, elegido con el selector de días y horas
/// (no texto libre).
///
/// En la base de datos se sigue guardando como texto (`horario`), pero
/// siempre con el mismo formato, legible para el visitante y fácil de leer de
/// vuelta para editarlo:
///
///   Lun–Vie 9:00 AM – 6:00 PM · Sáb 10:00 AM – 2:00 PM · Dom Cerrado
///
/// Los días seguidos con el mismo horario se agrupan ("Lun–Vie"). Un texto
/// que no tenga este formato (los horarios escritos a mano antes del
/// selector) no se puede leer: [HorarioSemanal.parse] regresa null.
class HorarioSemanal {
  /// Siempre 7 días, de lunes (0) a domingo (6).
  final List<HorarioDia> dias;

  HorarioSemanal(List<HorarioDia> dias) : dias = List.unmodifiable(dias) {
    assert(dias.length == 7);
  }

  static const abreviaturas = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
  static const nombres = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];

  /// Punto de partida al configurar un horario nuevo: lunes a viernes de
  /// 9:00 AM a 6:00 PM y fin de semana cerrado.
  factory HorarioSemanal.predeterminado() => HorarioSemanal([
        for (var i = 0; i < 7; i++)
          i < 5 ? const HorarioDia.abierto(9 * 60, 18 * 60) : const HorarioDia.cerrado(),
      ]);

  bool get algunDiaAbierto => dias.any((d) => d.abierto);

  HorarioSemanal conDia(int indice, HorarioDia dia) {
    final copia = [...dias];
    copia[indice] = dia;
    return HorarioSemanal(copia);
  }

  /// Copia el horario de [indice] a los demás días abiertos (los cerrados se
  /// quedan cerrados).
  HorarioSemanal copiarATodos(int indice) {
    final base = dias[indice];
    return HorarioSemanal([
      for (var i = 0; i < 7; i++) i == indice || !dias[i].abierto ? dias[i] : base,
    ]);
  }

  /// Texto con el formato fijo (ver arriba).
  String formatear() {
    final partes = <String>[];
    var i = 0;
    while (i < 7) {
      var fin = i;
      while (fin + 1 < 7 && dias[fin + 1] == dias[i]) {
        fin++;
      }
      final nombre = fin == i ? abreviaturas[i] : '${abreviaturas[i]}–${abreviaturas[fin]}';
      partes.add('$nombre ${dias[i].formatear()}');
      i = fin + 1;
    }
    return partes.join(' · ');
  }

  @override
  String toString() => formatear();

  static final _segmento = RegExp(
    r'^(Lun|Mar|Mié|Jue|Vie|Sáb|Dom)(?:–(Lun|Mar|Mié|Jue|Vie|Sáb|Dom))? '
    r'(?:(Cerrado)|(\d{1,2}):(\d{2}) (AM|PM) – (\d{1,2}):(\d{2}) (AM|PM))$',
  );

  /// Lee un horario guardado con [formatear]. null si el texto está vacío o
  /// tiene otro formato (p. ej. uno escrito a mano antes del selector).
  static HorarioSemanal? parse(String? texto) {
    final t = texto?.trim();
    if (t == null || t.isEmpty) return null;
    final dias = List<HorarioDia?>.filled(7, null);
    for (final parte in t.split(' · ')) {
      final m = _segmento.firstMatch(parte.trim());
      if (m == null) return null;
      final desde = abreviaturas.indexOf(m.group(1)!);
      final hasta = m.group(2) == null ? desde : abreviaturas.indexOf(m.group(2)!);
      if (hasta < desde) return null;
      HorarioDia dia;
      if (m.group(3) != null) {
        dia = const HorarioDia.cerrado();
      } else {
        final abre = _minutos(m.group(4)!, m.group(5)!, m.group(6)!);
        final cierra = _minutos(m.group(7)!, m.group(8)!, m.group(9)!);
        if (abre == null || cierra == null) return null;
        dia = HorarioDia.abierto(abre, cierra);
      }
      for (var d = desde; d <= hasta; d++) {
        if (dias[d] != null) return null; // un día repetido
        dias[d] = dia;
      }
    }
    if (dias.any((d) => d == null)) return null; // faltan días
    return HorarioSemanal(dias.cast<HorarioDia>());
  }

  static int? _minutos(String hora, String minuto, String periodo) {
    final h = int.parse(hora);
    final m = int.parse(minuto);
    if (h < 1 || h > 12 || m > 59) return null;
    return HoraDelDia.desde12(h, m, periodo == 'PM');
  }
}

/// Un día del horario: cerrado, o abierto de [abre] a [cierra] (minutos desde
/// la medianoche). Si [cierra] es menor que [abre], cierra al día siguiente
/// (p. ej. un bar de 8:00 PM a 2:00 AM).
class HorarioDia {
  final bool abierto;
  final int abre;
  final int cierra;

  const HorarioDia.abierto(this.abre, this.cierra) : abierto = true;
  const HorarioDia.cerrado()
      : abierto = false,
        abre = 9 * 60,
        cierra = 18 * 60;

  /// Abre y cierra a la misma hora: no tiene sentido.
  bool get horasIguales => abierto && abre == cierra;

  HorarioDia conAbierto(bool valor) => valor ? HorarioDia.abierto(abre, cierra) : const HorarioDia.cerrado();

  String formatear() => abierto ? '${HoraDelDia.formatear(abre)} – ${HoraDelDia.formatear(cierra)}' : 'Cerrado';

  @override
  bool operator ==(Object other) =>
      other is HorarioDia &&
      other.abierto == abierto &&
      (!abierto || (other.abre == abre && other.cierra == cierra));

  @override
  int get hashCode => abierto ? Object.hash(abre, cierra) : 0;
}

/// Ayudas para horas en formato de 12 horas (con AM/PM).
class HoraDelDia {
  HoraDelDia._();

  /// Minutos desde la medianoche a partir de hora (1–12), minuto y AM/PM.
  static int desde12(int hora, int minuto, bool pm) {
    final h24 = (hora % 12) + (pm ? 12 : 0);
    return h24 * 60 + minuto;
  }

  static int hora12(int minutos) {
    final h = (minutos ~/ 60) % 12;
    return h == 0 ? 12 : h;
  }

  static int minuto(int minutos) => minutos % 60;

  static bool esPm(int minutos) => minutos >= 12 * 60;

  static String formatear(int minutos) =>
      '${hora12(minutos)}:${minuto(minutos).toString().padLeft(2, '0')} ${esPm(minutos) ? 'PM' : 'AM'}';
}
