import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/api_service.dart';
import '../services/image_helper.dart';
import '../services/notification_service.dart';
import '../views/login_view.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.usuario});

  final Map<String, dynamic> usuario;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final Map<String, dynamic> _usuario;
  late final TextEditingController _nombreController;
  final _cedulaController = TextEditingController();
  List<Map<String, dynamic>> _amigos = [];
  List<Map<String, dynamic>> _cajeros = [];
  List<Map<String, dynamic>> _sucursales = [];
  Timer? _notificacionesTimer;
  double _saldo = 0;
  bool _guardandoPerfil = false;
  bool _subiendoFoto = false;
  bool _cargandoAmigos = true;
  bool _cargandoPuntos = true;
  bool _consultandoNotificaciones = false;

  String get _cedula => _usuario['cedula']?.toString() ?? '';
  String get _fotoUrl => _usuario['fotoUrl']?.toString() ?? '';

  @override
  void initState() {
    super.initState();
    _usuario = Map<String, dynamic>.from(widget.usuario);
    _nombreController = TextEditingController(text: _usuario['nombre']?.toString() ?? '');
    _cedulaController.text = _cedula;
    _saldo = (_usuario['saldo'] as num?)?.toDouble() ?? 0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cargarAmigos();
      _cargarPuntosAtencion();
      _iniciarNotificaciones();
    });
  }

  @override
  void dispose() {
    _notificacionesTimer?.cancel();
    _nombreController.dispose();
    _cedulaController.dispose();
    super.dispose();
  }

  Future<void> _cargarAmigos() async {
    try {
      final amigos = await ApiService.getFriends(_cedula);
      if (mounted) setState(() => _amigos = amigos);
    } on ApiFailure catch (error) {
      if (mounted) _mostrarMensaje(error.message, error: true);
    } finally {
      if (mounted) setState(() => _cargandoAmigos = false);
    }
  }

  Future<void> _cargarPuntosAtencion() async {
    try {
      final points = await ApiService.getServicePoints();
      if (!mounted) return;
      setState(() {
        _cajeros = List<Map<String, dynamic>>.from(points['cajeros'] as List? ?? const []);
        _sucursales = List<Map<String, dynamic>>.from(points['sucursales'] as List? ?? const []);
      });
    } on ApiFailure catch (error) {
      if (mounted) _mostrarMensaje(error.message, error: true);
    } finally {
      if (mounted) setState(() => _cargandoPuntos = false);
    }
  }

  Future<void> _iniciarNotificaciones() async {
    if (!await NotificationService.solicitarPermiso(context) || !mounted) return;
    await _consultarNotificaciones();
    _notificacionesTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _consultarNotificaciones(),
    );
  }

  Future<void> _consultarNotificaciones() async {
    if (_consultandoNotificaciones || _cedula.isEmpty) return;
    _consultandoNotificaciones = true;
    try {
      final avisos = await ApiService.getNotifications(_cedula);
      for (final aviso in avisos) {
        await NotificationService.mostrarNotificacion(
          id: (aviso['id'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
          titulo: aviso['titulo']?.toString() ?? 'Finanzas 360',
          cuerpo: aviso['cuerpo']?.toString() ?? '',
        );
      }
    } on ApiFailure catch (error) {
      debugPrint('No se pudieron consultar notificaciones: ${error.message}');
    } finally {
      _consultandoNotificaciones = false;
    }
  }

  Future<void> _seleccionarFoto() async {
    ImageHelper.seleccionarImagen(context, (XFile imagen) async {
      setState(() => _subiendoFoto = true);
      try {
        final url = await ApiService.uploadProfileImage(identifier: _cedula, image: imagen);
        if (!mounted) return;
        setState(() => _usuario['fotoUrl'] = url);
        _mostrarMensaje('Foto de perfil guardada');
      } on ApiFailure catch (error) {
        if (mounted) _mostrarMensaje(error.message, error: true);
      } finally {
        if (mounted) setState(() => _subiendoFoto = false);
      }
    });
  }

  Future<void> _guardarPerfil() async {
    if (_guardandoPerfil || _nombreController.text.trim().isEmpty) {
      _mostrarMensaje('Ingrese su nombre completo', error: true);
      return;
    }
    setState(() => _guardandoPerfil = true);
    try {
      final usuario = await ApiService.updateProfile(
        identifier: _cedula,
        name: _nombreController.text.trim(),
      );
      if (!mounted) return;
      _usuario.addAll(usuario);
      _mostrarMensaje('Información del perfil guardada');
      await _cargarAmigos();
    } on ApiFailure catch (error) {
      if (mounted) _mostrarMensaje(error.message, error: true);
    } finally {
      if (mounted) setState(() => _guardandoPerfil = false);
    }
  }

  Future<void> _abrirTransferencia(Map<String, dynamic> amigo) async {
    final montoController = TextEditingController();
    final monto = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Enviar a ${amigo['nombre'] ?? 'amigo'}'),
        content: TextField(
          controller: montoController,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Monto', prefixText: '\$ '),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final parsed = double.tryParse(montoController.text.trim().replaceAll(',', '.'));
              if (parsed == null || parsed <= 0) {
                _mostrarMensaje('Ingrese un monto válido', error: true);
                return;
              }
              Navigator.pop(dialogContext, parsed);
            },
            child: const Text('Transferir'),
          ),
        ],
      ),
    );
    montoController.dispose();
    if (monto == null || !mounted) return;
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirmar transferencia'),
        content: Text(
          '¿Estás seguro de transferir \$${monto.toStringAsFixed(2)} a ${amigo['nombre']}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (confirmado == true) await _realizarTransferencia(amigo, monto);
  }

  Future<void> _realizarTransferencia(Map<String, dynamic> amigo, double monto) async {
    try {
      final resultado = await ApiService.transfer(
        sender: _cedula,
        recipient: amigo['cedula'].toString(),
        amount: monto,
      );
      if (!mounted) return;
      setState(() => _saldo = (resultado['saldo'] as num?)?.toDouble() ?? _saldo);
      final notificacion = resultado['notificacionEmisor'];
      if (notificacion is Map) {
        try {
          await NotificationService.mostrarNotificacion(
            id: DateTime.now().millisecondsSinceEpoch.remainder(2147483647),
            titulo: notificacion['titulo']?.toString() ?? 'Transferencia realizada con éxito',
            cuerpo: notificacion['cuerpo']?.toString() ??
                'Transferencia realizada con éxito: Enviaste \$${monto.toStringAsFixed(2)} a ${amigo['nombre']}',
          );
        } catch (error) {
          debugPrint('No se pudo mostrar la notificación local: $error');
        }
      }
      _mostrarMensaje('Transferencia enviada correctamente');
      await _cargarAmigos();
      await _consultarNotificaciones();
    } on ApiFailure catch (error) {
      if (mounted) _mostrarMensaje(error.message, error: true);
    }
  }

  void _mostrarMensaje(String mensaje, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: error ? Colors.red.shade700 : null,
      ),
    );
  }

  Future<void> _cerrarSesion() async {
    await ApiService.logout();
    if (!mounted) return;
    await Navigator.of(context).pushAndRemoveUntil<void>(
      MaterialPageRoute<void>(builder: (_) => const LoginView()),
      (_) => false,
    );
  }

  Widget _foto({required double radio}) {
    return CircleAvatar(
      radius: radio,
      backgroundImage: _fotoUrl.isNotEmpty ? NetworkImage(_fotoUrl) : null,
      child: _fotoUrl.isEmpty ? Icon(Icons.person, size: radio, color: Colors.white) : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi perfil'),
        actions: [
          IconButton(
            onPressed: _cerrarSesion,
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Center(
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    _foto(radio: 52),
                    IconButton.filled(
                      onPressed: _subiendoFoto ? null : _seleccionarFoto,
                      tooltip: 'Cambiar foto de perfil',
                      icon: _subiendoFoto
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.camera_alt),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(_usuario['rol']?.toString().toUpperCase() ?? 'CLIENTE'),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Card(
            child: ListTile(
              leading: const Icon(Icons.account_balance_wallet_outlined),
              title: const Text('Saldo disponible'),
              trailing: Text('\$${_saldo.toStringAsFixed(2)}', style: Theme.of(context).textTheme.titleLarge),
            ),
          ),
          const SizedBox(height: 20),
          Text('Datos personales', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          TextField(
            controller: _nombreController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Nombre Completo'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _cedulaController,
            readOnly: true,
            decoration: const InputDecoration(labelText: 'Cédula / Usuario'),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _guardandoPerfil ? null : _guardarPerfil,
            icon: _guardandoPerfil
                ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save_outlined),
            label: const Text('Guardar datos'),
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(child: Text('Amigos y transferencias', style: Theme.of(context).textTheme.titleLarge)),
              IconButton(
                onPressed: _cargarAmigos,
                tooltip: 'Actualizar amigos',
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_cargandoAmigos)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
          else if (_amigos.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Text('Todavía no hay otros usuarios para transferir.'),
            )
          else
            ..._amigos.map((amigo) {
              final foto = amigo['fotoUrl']?.toString() ?? '';
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundImage: foto.isNotEmpty ? NetworkImage(foto) : null,
                    child: foto.isEmpty ? const Icon(Icons.person) : null,
                  ),
                  title: Text(amigo['nombre']?.toString() ?? 'Usuario'),
                  subtitle: Text('Saldo: \$${((amigo['saldo'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}'),
                  trailing: IconButton.filledTonal(
                    onPressed: () => _abrirTransferencia(amigo),
                    tooltip: 'Transferir dinero',
                    icon: const Icon(Icons.send),
                  ),
                ),
              );
            }),
          const SizedBox(height: 28),
          Text('Puntos de atención', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          if (_cargandoPuntos)
            const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
          else ...[
            ..._cajeros.map((cajero) => ListTile(
                  leading: const Icon(Icons.support_agent),
                  title: Text(cajero['nombre']?.toString() ?? 'Cajero'),
                  subtitle: Text(cajero['sucursal']?.toString() ?? 'Cajero disponible'),
                )),
            ..._sucursales.map((sucursal) => ListTile(
                  leading: const Icon(Icons.storefront_outlined),
                  title: Text(sucursal['nombre']?.toString() ?? 'Sucursal'),
                  subtitle: Text(sucursal['direccion']?.toString() ?? ''),
                )),
          ],
        ],
      ),
    );
  }
}
