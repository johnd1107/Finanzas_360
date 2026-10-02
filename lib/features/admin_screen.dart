import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../core/constants/app_theme.dart';
import '../services/api_service.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _todosLosUsuarios = [];
  List<dynamic> _todosLosClientes = [];
  List<dynamic> _clientesFiltrados = [];
  List<Map<String, dynamic>> _cajeros = [];
  List<Map<String, dynamic>> _sucursales = [];
  List<Map<String, dynamic>> _operaciones = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _obtenerClientesDelBackend();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _obtenerClientesDelBackend() async {
    try {
      final resultados = await Future.wait([
        ApiService.getUsers(),
        ApiService.getCashiers(),
        ApiService.getBranches(),
        ApiService.getOperations(),
      ]);
      if (!mounted) return;
      setState(() {
        _todosLosUsuarios = resultados[0];
        _todosLosClientes = _todosLosUsuarios.where((user) => user['rol'] == 'cliente').toList();
        _clientesFiltrados = _todosLosClientes;
        _cajeros = resultados[1];
        _sucursales = resultados[2];
        _operaciones = resultados[3];
        _cargando = false;
      });
    } on ApiFailure catch (error) {
      if (mounted) {
        setState(() => _cargando = false);
        _mostrarError(error.message);
      }
    } catch (e) {
      setState(() => _cargando = false);
      if (mounted) {
        _mostrarError('Error al conectar con el backend: $e');
      }
    }
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  void _filtrarPorCedula(String query) {
    final normalizedQuery = query.trim().toLowerCase();
    setState(() {
      _clientesFiltrados = _todosLosClientes
          .where((cliente) =>
              cliente['cedula'].toString().toLowerCase().contains(normalizedQuery) ||
              cliente['nombre'].toString().toLowerCase().contains(normalizedQuery))
          .toList();
    });
  }

  Future<void> _generarPdf() async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Finanzas360 - Reporte de Usuarios',
                  style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 15),
              pw.TableHelper.fromTextArray(
                headers: ['Cédula / Usuario', 'Nombre', 'Rol', 'Saldo'],
                data: _todosLosUsuarios
                  .map((user) => [user['cedula'], user['nombre'], user['rol'], '\$${user['saldo']}'])
                    .toList(),
              ),
            ],
          );
        },
      ),
    );
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  Future<void> _crearCajero() async {
    final nameController = TextEditingController();
    final identifierController = TextEditingController();
    final passwordController = TextEditingController();
    final branchController = TextEditingController(text: 'Sucursal Centro');
    final values = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Registrar cajero'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nombre completo')),
              TextField(controller: identifierController, decoration: const InputDecoration(labelText: 'Usuario')),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Contraseña (mínimo 10 caracteres)'),
              ),
              TextField(controller: branchController, decoration: const InputDecoration(labelText: 'Sucursal')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              if (nameController.text.trim().isEmpty ||
                  identifierController.text.trim().isEmpty ||
                  passwordController.text.length < 10) {
                _mostrarError('Complete los campos y use una contraseña de al menos 10 caracteres');
                return;
              }
              Navigator.pop(dialogContext, {
                'nombre': nameController.text.trim(),
                'identificador': identifierController.text.trim(),
                'contrasena': passwordController.text,
                'sucursal': branchController.text.trim(),
              });
            },
            child: const Text('Crear cajero'),
          ),
        ],
      ),
    );
    nameController.dispose();
    identifierController.dispose();
    passwordController.dispose();
    branchController.dispose();
    if (values == null) return;

    try {
      await ApiService.createCashier(
        identifier: values['identificador']!,
        name: values['nombre']!,
        password: values['contrasena']!,
        branch: values['sucursal']!,
      );
      if (!mounted) return;
      _mostrarError('Cajero registrado exitosamente');
      await _obtenerClientesDelBackend();
    } on ApiFailure catch (error) {
      if (mounted) _mostrarError(error.message);
    }
  }

  Future<void> _ajustarSaldo(Map<String, dynamic> user) async {
    final controller = TextEditingController(
      text: ((user['saldo'] as num?)?.toDouble() ?? 0).toStringAsFixed(2),
    );
    final balance = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Ajustar saldo de ${user['nombre']}'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Nuevo saldo', prefixText: '\$ '),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final value = double.tryParse(controller.text.trim().replaceAll(',', '.'));
              if (value == null || value < 0) {
                _mostrarError('Ingrese un saldo válido mayor o igual a cero');
                return;
              }
              Navigator.pop(dialogContext, value);
            },
            child: const Text('Guardar ajuste'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (balance == null) return;
    try {
      await ApiService.adjustBalance(identifier: user['cedula'].toString(), balance: balance);
      if (mounted) {
        _mostrarError('Saldo ajustado correctamente');
        await _obtenerClientesDelBackend();
      }
    } on ApiFailure catch (error) {
      if (mounted) _mostrarError(error.message);
    }
  }

  Future<void> _eliminarUsuario(Map<String, dynamic> user) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar usuario'),
        content: Text('¿Desea eliminar a ${user['nombre']}? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmado != true) return;
    try {
      await ApiService.deleteUser(user['cedula'].toString());
      if (mounted) {
        _mostrarError('Usuario eliminado');
        await _obtenerClientesDelBackend();
      }
    } on ApiFailure catch (error) {
      if (mounted) _mostrarError(error.message);
    }
  }

  Future<void> _cerrarSesion() async {
    await ApiService.logout();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Administración'),
          actions: [
            IconButton(
              onPressed: _crearCajero,
              tooltip: 'Registrar cajero',
              icon: const Icon(Icons.person_add_alt_1),
            ),
            IconButton(
              onPressed: _cerrarSesion,
              tooltip: 'Cerrar sesión',
              icon: const Icon(Icons.logout),
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Clientes'),
              Tab(text: 'Cajeros'),
              Tab(text: 'Sucursales'),
              Tab(text: 'Operaciones'),
            ],
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: _filtrarPorCedula,
                      decoration: const InputDecoration(
                        hintText: 'Buscar clientes por cédula o nombre...',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filled(
                    style: IconButton.styleFrom(backgroundColor: AppTheme.emeraldGreen),
                    icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                    onPressed: _generarPdf,
                    tooltip: 'Imprimir reporte global de usuarios',
                  ),
                  IconButton(
                    onPressed: _obtenerClientesDelBackend,
                    tooltip: 'Actualizar datos',
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              Expanded(
                child: _cargando
                    ? const Center(child: CircularProgressIndicator())
                    : TabBarView(
                        children: [
                          _buildUserList(_clientesFiltrados),
                          _buildUserList(_cajeros),
                          _buildBranchList(),
                          _buildOperationsList(),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserList(List<dynamic> users) {
    if (users.isEmpty) return const Center(child: Text('No hay registros para mostrar'));
    return ListView.builder(
      padding: const EdgeInsets.only(top: 12),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index] as Map<String, dynamic>;
        final foto = user['fotoUrl']?.toString() ?? '';
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppTheme.primaryDark,
              backgroundImage: foto.isNotEmpty ? NetworkImage(foto) : null,
              child: foto.isEmpty ? const Icon(Icons.person, color: Colors.white) : null,
            ),
            title: Text(user['nombre']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(
              'Cédula: ${user['cedula']} · ${user['rol'] ?? 'usuario'}\n'
              'Saldo: \$${((user['saldo'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}',
            ),
            isThreeLine: true,
            trailing: PopupMenuButton<String>(
              tooltip: 'Acciones de administrador',
              onSelected: (action) {
                if (action == 'balance') _ajustarSaldo(user);
                if (action == 'delete') _eliminarUsuario(user);
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'balance', child: Text('Ajustar saldo')),
                PopupMenuItem(value: 'delete', child: Text('Eliminar usuario')),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOperationsList() {
    if (_operaciones.isEmpty) return const Center(child: Text('No hay operaciones registradas'));
    return ListView.builder(
      padding: const EdgeInsets.only(top: 12),
      itemCount: _operaciones.length,
      itemBuilder: (context, index) {
        final operation = _operaciones[_operaciones.length - index - 1];
        final amount = operation['monto'] as num?;
        final detail = operation['tipo'] == 'transferencia'
            ? '${operation['remitente']} → ${operation['destinatario']}'
            : 'Usuario: ${operation['usuario'] ?? ''} · Actor: ${operation['actor'] ?? ''}';
        return Card(
          child: ListTile(
            leading: Icon(operation['tipo'] == 'transferencia' ? Icons.swap_horiz : Icons.receipt_long),
            title: Text(operation['tipo']?.toString() ?? 'Operación'),
            subtitle: Text('$detail\n${operation['fecha'] ?? ''}'),
            isThreeLine: true,
            trailing: amount == null ? null : Text('\$${amount.toStringAsFixed(2)}'),
          ),
        );
      },
    );
  }

  Widget _buildBranchList() {
    if (_sucursales.isEmpty) return const Center(child: Text('No hay sucursales registradas'));
    return ListView.builder(
      padding: const EdgeInsets.only(top: 12),
      itemCount: _sucursales.length,
      itemBuilder: (context, index) {
        final branch = _sucursales[index];
        final services = (branch['servicios'] as List<dynamic>? ?? []).join(' · ');
        return Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.storefront_outlined)),
            title: Text(branch['nombre']?.toString() ?? ''),
            subtitle: Text('${branch['direccion'] ?? ''}\n$services'),
            isThreeLine: true,
          ),
        );
      },
    );
  }
}
