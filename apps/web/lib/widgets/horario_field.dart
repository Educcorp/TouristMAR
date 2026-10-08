import 'package:flutter/material.dart';

import '../models/horario.dart';
import '../theme/app_theme.dart';

/// Campo "Horario" del negocio: en vez de texto libre, se despliega la lista
/// de los 7 días y en cada uno se marca si abre y, si abre, a qué hora abre y
/// cierra (hora, minutos y AM/PM con listas, sin escribir nada).
///
/// [onChanged] recibe el horario ya con el formato fijo de
/// [HorarioSemanal.formatear] (o null si todavía no se configura).
///
/// Si [inicial] es un horario escrito a mano antes de este selector, se
/// muestra como "formato anterior" y, mientras no se toque, se acepta solo si
/// [aceptarAnterior] es true.
class HorarioField extends StatefulWidget {
  final String? inicial;
  final ValueChanged<String?> onChanged;
  final Color acento;
  final bool habilitado;

  /// Exige al menos un día abierto.
  final bool obligatorio;

  /// Acepta un horario escrito a mano antes del selector (sin tocarlo).
  final bool aceptarAnterior;

  /// La etiqueta del campo ("Horario", "Horario (opcional)"…).
  final String etiqueta;

  // ignore: prefer_const_constructors_in_immutables
  HorarioField({
    super.key,
    required this.inicial,
    required this.onChanged,
    required this.acento,
    this.habilitado = true,
    this.obligatorio = true,
    this.aceptarAnterior = true,
    this.etiqueta = 'Horario',
  });

  @override
  State<HorarioField> createState() => _HorarioFieldState();
}

class _HorarioFieldState extends State<HorarioField> {
  final _campo = GlobalKey<FormFieldState<void>>();
  late HorarioSemanal? _horario = HorarioSemanal.parse(widget.inicial);

  /// Texto guardado antes del selector que no se pudo leer.
  late final String? _anterior =
      _horario == null && (widget.inicial?.trim().isNotEmpty ?? false) ? widget.inicial!.trim() : null;

  bool _expandido = false;

  @override
  void initState() {
    super.initState();
    // Si es obligatorio y todavía no hay un horario válido, se abre solo
    // (después del primer cuadro, para avisarle al formulario el valor
    // propuesto sin hacerlo durante la construcción).
    if (widget.obligatorio && _horario == null && !widget.aceptarAnterior) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_expandido) _alternar();
      });
    }
  }

  String? _validar() {
    final h = _horario;
    if (h == null) {
      if (_anterior != null && widget.aceptarAnterior) return null;
      return widget.obligatorio ? 'Elige los días y las horas en que abre tu negocio' : null;
    }
    if (!h.algunDiaAbierto) {
      return widget.obligatorio ? 'Marca al menos un día en que abre tu negocio' : null;
    }
    for (var i = 0; i < 7; i++) {
      if (h.dias[i].horasIguales) {
        return 'El ${HorarioSemanal.nombres[i].toLowerCase()} abre y cierra a la misma hora';
      }
    }
    return null;
  }

  void _cambiar(HorarioSemanal nuevo) {
    setState(() => _horario = nuevo);
    widget.onChanged(nuevo.formatear());
    if (_campo.currentState?.hasError ?? false) _campo.currentState!.validate();
  }

  void _alternar() {
    setState(() {
      _expandido = !_expandido;
      // Al abrirlo por primera vez se propone un horario común para que solo
      // haya que ajustarlo.
      if (_expandido && _horario == null) {
        _horario = HorarioSemanal.predeterminado();
        widget.onChanged(_horario!.formatear());
      }
    });
  }

  String get _resumen {
    final h = _horario;
    if (h != null) return h.algunDiaAbierto ? h.formatear() : 'Cerrado todos los días';
    if (_anterior != null) return 'Formato anterior: "$_anterior". Toca para elegir días y horas.';
    return 'Sin configurar. Toca para elegir días y horas.';
  }

  @override
  Widget build(BuildContext context) {
    return FormField<void>(
      key: _campo,
      validator: (_) => _validar(),
      builder: (field) {
        final error = field.errorText;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.etiqueta, style: TextStyle(color: AppColors.slate300, fontSize: 14)),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: AppColors.panelNavySoft,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: error != null ? AppColors.errorRed : AppColors.overlay(0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  InkWell(
                    key: const ValueKey('horario-desplegar'),
                    borderRadius: BorderRadius.circular(8),
                    onTap: widget.habilitado ? _alternar : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      child: Row(
                        children: [
                          Icon(Icons.schedule_outlined, size: 18, color: AppColors.slate500),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _resumen,
                              style: TextStyle(
                                color: _horario == null ? AppColors.slate500 : AppColors.textPrimary,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Icon(_expandido ? Icons.expand_less : Icons.expand_more, color: AppColors.slate400),
                        ],
                      ),
                    ),
                  ),
                  if (_expandido && _horario != null) ...[
                    Divider(height: 1, color: AppColors.overlay(0.08)),
                    for (var i = 0; i < 7; i++)
                      _FilaDia(
                        indice: i,
                        dia: _horario!.dias[i],
                        acento: widget.acento,
                        habilitado: widget.habilitado,
                        onChanged: (d) => _cambiar(_horario!.conDia(i, d)),
                        onCopiar: () {
                          _cambiar(_horario!.copiarATodos(i));
                          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                            SnackBar(content: Text('Horario del ${HorarioSemanal.nombres[i].toLowerCase()} copiado a los días abiertos')),
                          );
                        },
                      ),
                  ],
                ],
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 6),
              Text(error, style: TextStyle(color: AppColors.errorRed, fontSize: 12)),
            ],
          ],
        );
      },
    );
  }
}

class _FilaDia extends StatelessWidget {
  final int indice;
  final HorarioDia dia;
  final Color acento;
  final bool habilitado;
  final ValueChanged<HorarioDia> onChanged;
  final VoidCallback onCopiar;

  // ignore: prefer_const_constructors_in_immutables
  _FilaDia({
    required this.indice,
    required this.dia,
    required this.acento,
    required this.habilitado,
    required this.onChanged,
    required this.onCopiar,
  });

  @override
  Widget build(BuildContext context) {
    final nombre = HorarioSemanal.nombres[indice];
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(nombre, style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
              ),
              Text(
                dia.abierto ? 'Abierto' : 'Cerrado',
                style: TextStyle(color: dia.abierto ? acento : AppColors.slate500, fontSize: 12),
              ),
              Switch(
                key: ValueKey('horario-$indice-abierto'),
                value: dia.abierto,
                activeThumbColor: acento,
                onChanged: habilitado ? (v) => onChanged(dia.conAbierto(v)) : null,
              ),
            ],
          ),
          if (dia.abierto) ...[
            Wrap(
              spacing: 16,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _SelectorHora(
                  claveBase: 'horario-$indice-abre',
                  etiqueta: 'Abre',
                  minutos: dia.abre,
                  habilitado: habilitado,
                  onChanged: (m) => onChanged(HorarioDia.abierto(m, dia.cierra)),
                ),
                _SelectorHora(
                  claveBase: 'horario-$indice-cierra',
                  etiqueta: 'Cierra',
                  minutos: dia.cierra,
                  habilitado: habilitado,
                  onChanged: (m) => onChanged(HorarioDia.abierto(dia.abre, m)),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: habilitado ? onCopiar : null,
                icon: Icon(Icons.content_copy, size: 14, color: acento),
                label: Text('Usar este horario en los demás días abiertos', style: TextStyle(color: acento, fontSize: 12)),
              ),
            ),
            if (dia.horasIguales)
              Text('Abre y cierra a la misma hora', style: TextStyle(color: AppColors.errorRed, fontSize: 12)),
          ],
          if (indice < 6) Padding(padding: const EdgeInsets.only(top: 4), child: Divider(height: 1, color: AppColors.overlay(0.06))),
        ],
      ),
    );
  }
}

/// Hora con tres listas: hora (1–12), minutos y AM/PM.
class _SelectorHora extends StatelessWidget {
  final String claveBase;
  final String etiqueta;
  final int minutos;
  final bool habilitado;
  final ValueChanged<int> onChanged;

  // ignore: prefer_const_constructors_in_immutables
  _SelectorHora({
    required this.claveBase,
    required this.etiqueta,
    required this.minutos,
    required this.habilitado,
    required this.onChanged,
  });

  static const _minutosDisponibles = [0, 15, 30, 45];

  @override
  Widget build(BuildContext context) {
    final hora = HoraDelDia.hora12(minutos);
    final minuto = HoraDelDia.minuto(minutos);
    final pm = HoraDelDia.esPm(minutos);
    final opcionesMinuto = {..._minutosDisponibles, minuto}.toList()..sort();

    void cambiar({int? h, int? m, bool? esPm}) => onChanged(HoraDelDia.desde12(h ?? hora, m ?? minuto, esPm ?? pm));

    return Wrap(
      spacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 48,
          child: Text(etiqueta, style: TextStyle(color: AppColors.slate400, fontSize: 12)),
        ),
        _Lista<int>(
          clave: '$claveBase-hora',
          valor: hora,
          opciones: [for (var h = 1; h <= 12; h++) h],
          texto: (h) => '$h',
          habilitado: habilitado,
          onChanged: (h) => cambiar(h: h),
        ),
        Text(':', style: TextStyle(color: AppColors.slate400, fontSize: 13)),
        _Lista<int>(
          clave: '$claveBase-minuto',
          valor: minuto,
          opciones: opcionesMinuto,
          texto: (m) => m.toString().padLeft(2, '0'),
          habilitado: habilitado,
          onChanged: (m) => cambiar(m: m),
        ),
        _Lista<bool>(
          clave: '$claveBase-periodo',
          valor: pm,
          opciones: const [false, true],
          texto: (p) => p ? 'PM' : 'AM',
          habilitado: habilitado,
          onChanged: (p) => cambiar(esPm: p),
        ),
      ],
    );
  }
}

class _Lista<T> extends StatelessWidget {
  final String clave;
  final T valor;
  final List<T> opciones;
  final String Function(T) texto;
  final bool habilitado;
  final ValueChanged<T> onChanged;

  // ignore: prefer_const_constructors_in_immutables
  _Lista({
    required this.clave,
    required this.valor,
    required this.opciones,
    required this.texto,
    required this.habilitado,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.panelNavy,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.overlay(0.1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          key: ValueKey(clave),
          value: valor,
          isDense: true,
          dropdownColor: AppColors.panelNavySoft,
          style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
          icon: Icon(Icons.keyboard_arrow_down, size: 16, color: AppColors.slate400),
          items: [for (final o in opciones) DropdownMenuItem<T>(value: o, child: Text(texto(o)))],
          onChanged: habilitado
              ? (v) {
                  if (v != null) onChanged(v);
                }
              : null,
        ),
      ),
    );
  }
}
