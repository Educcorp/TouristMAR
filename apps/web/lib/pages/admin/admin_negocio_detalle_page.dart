import 'package:flutter/material.dart';

import '../../models/lugar.dart';
import '../../services/auth_service.dart';
import '../../services/image_picker_service.dart';
import '../../services/session_storage.dart';
import '../../theme/app_theme.dart';
import '../../utils/date_format_es.dart';
import '../../utils/keyboard.dart';
import '../../widgets/admin/ds_badge.dart';
import '../../widgets/admin/ds_button.dart';
import '../../widgets/admin/ds_card.dart';
import '../../widgets/admin/ds_states.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/mapa/ubicacion_lugar.dart';
import '../../widgets/themed_builder.dart';

/// Contenido de RA que el admin puede ligar a un negocio desde su solicitud.
enum ContenidoNegocio { realidadAumentada, recorrido360 }

/// Lo que pasó en el detalle, para que quien lo abrió actualice su vista.
class ResultadoDetalleNegocio {
  final String negocioId;

  /// `true` = aprobado, `false` = rechazado, `null` = sin decidir.
  final bool? aprobado;

  /// Si el admin pidió ir a añadir contenido de RA para este negocio (se
  /// agrega en su ficha dentro de "Mapa y RA").
  final ContenidoNegocio? abrirContenido;

  /// Si se guardaron cambios en los datos (para recargar listas).
  final bool editado;

  const ResultadoDetalleNegocio({required this.negocioId, this.aprobado, this.abrirContenido, this.editado = false});
}

/// Abre el detalle de una solicitud de negocio en pantalla completa.
Future<ResultadoDetalleNegocio?> abrirDetalleNegocio(
  BuildContext context, {
  required String negocioId,
  AuthService? authService,
}) {
  hideKeyboard();
  return Navigator.of(context).push<ResultadoDetalleNegocio>(
    MaterialPageRoute(builder: (_) => AdminNegocioDetallePage(negocioId: negocioId, authService: authService)),
  );
}

/// Detalle de una solicitud de negocio para el administrador.
///
/// Muestra lo que la empresa mandó desde su panel (imagen, nombre, ubicación,
/// dirección, contacto…), deja corregir cualquiera de esos datos, añadir el
/// contenido de realidad aumentada (RA por marcador y recorrido 360) y, al
/// final, aprobar o rechazar la solicitud.
class AdminNegocioDetallePage extends StatefulWidget {
  final String negocioId;
  final AuthService authService;

  AdminNegocioDetallePage({super.key, required this.negocioId, AuthService? authService})
      : authService = authService ?? AuthService();

  @override
  State<AdminNegocioDetallePage> createState() => _AdminNegocioDetallePageState();
}

class _AdminNegocioDetallePageState extends State<AdminNegocioDetallePage> {
  final _formKey = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _categoria = TextEditingController();
  final _descripcion = TextEditingController();
  final _direccion = TextEditingController();
  final _telefono = TextEditingController();
  final _horario = TextEditingController();
  final _sitioWeb = TextEditingController();

  NegocioDetalle? _negocio;
  Coordenadas? _ubicacion;
  PickedImage? _portadaNueva;
  bool _loading = true;
  bool _saving = false;
  bool _deciding = false;
  bool _dirty = false;
  bool _editado = false;
  String? _error;

  List<TextEditingController> get _controllers =>
      [_nombre, _categoria, _descripcion, _direccion, _telefono, _horario, _sitioWeb];

  @override
  void initState() {
    super.initState();
    for (final c in _controllers) {
      c.addListener(_marcarCambio);
    }
    _load();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _marcarCambio() {
    if (!_dirty && _negocio != null && !_cargandoCampos) setState(() => _dirty = true);
  }

  bool _cargandoCampos = false;

  void _llenarCampos(NegocioDetalle n) {
    _cargandoCampos = true;
    _nombre.text = n.nombre;
    _categoria.text = n.categoria ?? '';
    _descripcion.text = n.descripcion ?? '';
    _direccion.text = n.direccion ?? '';
    _telefono.text = n.telefono ?? '';
    _horario.text = n.horario ?? '';
    _sitioWeb.text = n.sitioWeb ?? '';
    _cargandoCampos = false;
    _ubicacion = n.tieneUbicacion ? Coordenadas(n.latitud!, n.longitud!) : null;
    _portadaNueva = null;
    _dirty = false;
  }

  Future<void> _load() async {
    final token = SessionStorage.token;
    if (token == null) {
      setState(() {
        _loading = false;
        _error = 'Tu sesión expiró, vuelve a iniciar sesión';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final n = await widget.authService.adminGetNegocio(token, widget.negocioId);
      if (!mounted) return;
      setState(() {
        _negocio = n;
        _llenarCampos(n);
      });
    } catch (err) {
      if (!mounted) return;
      setState(() => _error = err is AuthError ? err.message : 'No se pudo conectar con el servidor');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _elegirPortada() async {
    final picked = await ImagePickerService.pick();
    if (picked == null || !mounted) return;
    setState(() {
      _portadaNueva = picked;
      _dirty = true;
    });
  }

  /// Guarda los datos editados (y la portada nueva, si hay). Devuelve `false`
  /// si algo falló — ya se avisó al admin.
  Future<bool> _guardar() async {
    if (!(_formKey.currentState?.validate() ?? false)) return false;
    final token = SessionStorage.token;
    if (token == null) return false;
    hideKeyboard();
    setState(() => _saving = true);
    try {
      String? texto(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
      var n = await widget.authService.adminUpdateNegocio(token, widget.negocioId, {
        'nombre': _nombre.text.trim(),
        'categoria': texto(_categoria),
        'descripcion': texto(_descripcion),
        'direccion': texto(_direccion),
        'telefono': texto(_telefono),
        'horario': texto(_horario),
        'sitioWeb': texto(_sitioWeb),
        'latitud': _ubicacion?.lat,
        'longitud': _ubicacion?.lng,
      });
      final portada = _portadaNueva;
      if (portada != null) {
        n = await widget.authService.adminUploadNegocioPortada(token, widget.negocioId, portada.bytes, portada.name);
      }
      if (!mounted) return true;
      setState(() {
        _negocio = n;
        _llenarCampos(n);
        _editado = true;
      });
      _aviso('Cambios guardados.');
      return true;
    } catch (err) {
      if (mounted) _aviso(err is AuthError ? err.message : 'No se pudieron guardar los cambios');
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _decidir(bool aprobar) async {
    final token = SessionStorage.token;
    if (token == null) return;
    // Si el admin corrigió datos y no los guardó, se guardan antes de
    // aprobar para que el negocio salga publicado ya corregido.
    if (_dirty && !await _guardar()) return;
    if (!mounted) return;
    setState(() => _deciding = true);
    try {
      if (aprobar) {
        await widget.authService.adminApproveNegocio(token, widget.negocioId);
      } else {
        await widget.authService.adminRejectNegocio(token, widget.negocioId);
      }
      if (!mounted) return;
      Navigator.of(context).pop(ResultadoDetalleNegocio(negocioId: widget.negocioId, aprobado: aprobar, editado: _editado));
    } catch (err) {
      if (!mounted) return;
      _aviso(err is AuthError ? err.message : 'No se pudo procesar la solicitud');
    } finally {
      if (mounted) setState(() => _deciding = false);
    }
  }

  Future<void> _abrirContenido(ContenidoNegocio contenido) async {
    if (_dirty && !await _guardar()) return;
    if (!mounted) return;
    Navigator.of(context).pop(
      ResultadoDetalleNegocio(negocioId: widget.negocioId, abrirContenido: contenido, editado: _editado),
    );
  }

  void _salir() {
    Navigator.of(context).pop(_editado ? ResultadoDetalleNegocio(negocioId: widget.negocioId, editado: true) : null);
  }

  void _aviso(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  @override
  Widget build(BuildContext context) => ThemedBuilder(builder: _buildScaffold);

  Widget _buildScaffold(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _salir();
      },
      child: Scaffold(
        backgroundColor: AppColors.panelNavy,
        appBar: AppBar(
          backgroundColor: AppColors.panelNavy,
          foregroundColor: AppColors.textPrimary,
          leading: IconButton(tooltip: 'Volver', icon: const Icon(Icons.arrow_back), onPressed: _salir),
          title: const Text('Solicitud de negocio', style: TextStyle(fontSize: 16)),
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _negocio == null) return Center(child: DsLoadingState(accent: AppColors.adminViolet));
    final n = _negocio;
    if (n == null) {
      return Center(child: DsErrorState(message: _error ?? 'No se encontró ese negocio', onRetry: _load));
    }
    final ocupado = _saving || _deciding;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        // Columna normal (no ListView): todo el detalle se construye de una
        // vez, así nada queda sin montar fuera de pantalla.
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Encabezado(negocio: n),
              const SizedBox(height: AppSpacing.xl),
              Form(
                key: _formKey,
                child: DsCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Titulo(icon: Icons.edit_note, texto: 'Datos enviados por la empresa'),
                      const SizedBox(height: 4),
                      Text(
                        'Puedes corregir cualquier dato antes de aprobar. Se guarda al pulsar "Guardar cambios".',
                        style: AppTypography.bodySmall,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _PortadaAdmin(
                        url: n.portada,
                        nueva: _portadaNueva,
                        onCambiar: ocupado ? null : _elegirPortada,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AppTextField(
                        label: 'Nombre del negocio',
                        icon: Icons.apartment,
                        controller: _nombre,
                        accentColor: AppColors.adminViolet,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'El nombre no puede quedar vacío' : null,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        label: 'Categoría',
                        icon: Icons.local_offer_outlined,
                        controller: _categoria,
                        accentColor: AppColors.adminViolet,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      CampoCoordenadas(
                        // Se vuelve a crear con lo guardado en el servidor.
                        key: ValueKey('coordenadas-${n.latitud}-${n.longitud}'),
                        lugar: n.nombre,
                        inicial: _ubicacion,
                        acento: AppColors.adminViolet,
                        habilitado: !ocupado,
                        onChanged: (v) => setState(() {
                          _ubicacion = v;
                          _dirty = true;
                        }),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        label: 'Dirección',
                        icon: Icons.place_outlined,
                        controller: _direccion,
                        accentColor: AppColors.adminViolet,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        label: 'Teléfono',
                        icon: Icons.phone_outlined,
                        controller: _telefono,
                        keyboardType: TextInputType.phone,
                        accentColor: AppColors.adminViolet,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        label: 'Horario',
                        icon: Icons.schedule_outlined,
                        controller: _horario,
                        accentColor: AppColors.adminViolet,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        label: 'Sitio web',
                        icon: Icons.language,
                        controller: _sitioWeb,
                        accentColor: AppColors.adminViolet,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        label: 'Descripción',
                        icon: Icons.notes,
                        controller: _descripcion,
                        maxLines: 4,
                        accentColor: AppColors.adminViolet,
                        validator: (v) => (v != null && v.trim().length > 350) ? 'Máximo 350 caracteres' : null,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Align(
                        alignment: Alignment.centerRight,
                        child: DsButton(
                          label: _saving ? 'Guardando...' : 'Guardar cambios',
                          icon: Icons.save_outlined,
                          variant: DsButtonVariant.primary,
                          accent: AppColors.adminViolet,
                          onPressed: _dirty && !ocupado ? _guardar : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _SeccionContenido(
                icon: Icons.view_in_ar_outlined,
                titulo: 'RA por marcador',
                descripcion: 'Imágenes (letrero, menú, placa) que la cámara de la app reconoce para mostrar información. '
                    'Se agregan en la ficha del lugar en "Mapa y RA".',
                vacio: 'Este negocio todavía no tiene marcadores de RA.',
                items: n.marcadores,
                boton: 'Añadir RA por marcador',
                onAnadir: ocupado ? null : () => _abrirContenido(ContenidoNegocio.realidadAumentada),
              ),
              const SizedBox(height: AppSpacing.lg),
              _SeccionContenido(
                icon: Icons.threesixty,
                titulo: 'Recorrido 3D / 360°',
                descripcion: 'Fotos 360° del lugar para recorrerlo desde la app antes de visitarlo. '
                    'Se agregan en la ficha del lugar en "Mapa y RA".',
                vacio: 'Este negocio todavía no tiene recorridos 360°.',
                items: n.recorridos,
                boton: 'Añadir recorrido 360°',
                onAnadir: ocupado ? null : () => _abrirContenido(ContenidoNegocio.recorrido360),
              ),
              if (n.pendiente) ...[
                const SizedBox(height: AppSpacing.xl),
                if (n.marcadores.isNotEmpty || n.recorridos.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Text(
                      'El contenido de RA ligado se publica en la app en cuanto apruebes la solicitud.',
                      style: AppTypography.bodySmall,
                    ),
                  ),
                // Wrap (no Row): en un celular angosto "Rechazar" + "Guardar y
                // aprobar" no caben en una línea; así el segundo baja de renglón
                // en vez de desbordarse.
                Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    if (_deciding)
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.slate400),
                      )
                    else ...[
                      DsButton(
                        label: 'Rechazar',
                        variant: DsButtonVariant.danger,
                        onPressed: ocupado ? null : () => _decidir(false),
                      ),
                      DsButton(
                        label: _dirty ? 'Guardar y aprobar' : 'Aprobar',
                        icon: Icons.check,
                        variant: DsButtonVariant.primary,
                        accent: AppColors.emerald,
                        onPressed: ocupado ? null : () => _decidir(true),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Encabezado extends StatelessWidget {
  final NegocioDetalle negocio;

  // ignore: prefer_const_constructors_in_immutables
  _Encabezado({required this.negocio});

  @override
  Widget build(BuildContext context) {
    final (texto, tono) = switch (negocio.estado) {
      'aprobado' => ('Aprobado', BadgeTone.success),
      'rechazado' => ('Rechazado', BadgeTone.danger),
      _ => ('Pendiente', BadgeTone.warning),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(negocio.nombre, style: AppTypography.h2, overflow: TextOverflow.ellipsis)),
            const SizedBox(width: AppSpacing.sm),
            DsBadge(text: texto, tone: tono),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.lg,
          runSpacing: 6,
          children: [
            _Dato(icon: Icons.person_outline, texto: negocio.contacto),
            _Dato(icon: Icons.mail_outline, texto: negocio.email),
            _Dato(icon: Icons.event_outlined, texto: 'Solicitado el ${formatDateEs(negocio.solicitadoEn)}'),
          ],
        ),
      ],
    );
  }
}

class _Dato extends StatelessWidget {
  final IconData icon;
  final String texto;

  const _Dato({required this.icon, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.slate500),
        const SizedBox(width: 6),
        Flexible(child: Text(texto, style: AppTypography.bodySmall, overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}

class _Titulo extends StatelessWidget {
  final IconData icon;
  final String texto;

  // ignore: prefer_const_constructors_in_immutables
  _Titulo({required this.icon, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.adminViolet),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(texto, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
        ),
      ],
    );
  }
}

/// Portada actual (o la nueva elegida, aún sin guardar) con botón para
/// cambiarla.
class _PortadaAdmin extends StatelessWidget {
  final String? url;
  final PickedImage? nueva;
  final VoidCallback? onCambiar;

  // ignore: prefer_const_constructors_in_immutables
  _PortadaAdmin({required this.url, required this.nueva, required this.onCambiar});

  @override
  Widget build(BuildContext context) {
    // Se arma paso a paso: en un ternario MemoryImage/NetworkImage no tienen
    // un tipo común inferible y Dart lo deja como Object?.
    ImageProvider? imagen;
    if (nueva != null) {
      imagen = MemoryImage(nueva!.bytes);
    } else if (url != null && url!.isNotEmpty) {
      imagen = NetworkImage(url!);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Imagen de portada', style: TextStyle(color: AppColors.slate300, fontSize: 14)),
        const SizedBox(height: 8),
        Container(
          height: 180,
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.panelNavySoft,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.overlay(0.1)),
            image: imagen == null ? null : DecorationImage(image: imagen, fit: BoxFit.cover),
          ),
          child: imagen == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.image_not_supported_outlined, size: 28, color: AppColors.slate500),
                      const SizedBox(height: 6),
                      Text('La empresa no envió imagen', style: AppTypography.bodySmall),
                    ],
                  ),
                )
              : null,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            DsButton(
              label: imagen == null ? 'Subir imagen' : 'Cambiar imagen',
              icon: Icons.add_photo_alternate_outlined,
              size: DsButtonSize.sm,
              onPressed: onCambiar,
            ),
            if (nueva != null) ...[
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  'Vista previa — se aplicará al guardar',
                  style: TextStyle(color: AppColors.amber, fontSize: 12),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _SeccionContenido extends StatelessWidget {
  final IconData icon;
  final String titulo;
  final String descripcion;
  final String vacio;
  final List<ContenidoLigado> items;
  final String boton;
  final VoidCallback? onAnadir;

  // ignore: prefer_const_constructors_in_immutables
  _SeccionContenido({
    required this.icon,
    required this.titulo,
    required this.descripcion,
    required this.vacio,
    required this.items,
    required this.boton,
    required this.onAnadir,
  });

  @override
  Widget build(BuildContext context) {
    return DsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Titulo(icon: icon, texto: titulo),
          const SizedBox(height: 4),
          Text(descripcion, style: AppTypography.bodySmall),
          const SizedBox(height: AppSpacing.md),
          if (items.isEmpty)
            Text(vacio, style: TextStyle(color: AppColors.slate500, fontSize: 13))
          else
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline, size: 16, color: item.activo ? AppColors.emerald : AppColors.slate500),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        item.titulo.isEmpty ? item.nombre : '${item.titulo} · ${item.nombre}',
                        style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!item.activo) const DsBadge(text: 'Inactivo', tone: BadgeTone.neutral),
                  ],
                ),
              ),
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerLeft,
            child: DsButton(
              label: boton,
              icon: Icons.add,
              size: DsButtonSize.sm,
              accent: AppColors.adminViolet,
              onPressed: onAnadir,
            ),
          ),
        ],
      ),
    );
  }
}
