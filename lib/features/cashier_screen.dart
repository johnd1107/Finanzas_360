import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../views/login_view.dart';

class CashierScreen extends StatefulWidget {
  const CashierScreen({super.key, required this.usuario});

  final Map<String, dynamic> usuario;

  @override
  State<CashierScreen> createState() => _CashierScreenState();
}

class _CashierScreenState extends State<CashierScreen> {
  List<Map<String, dynamic>> _clientes = [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarClientes();
  }

  Future<void> _cargarClientes() async {
    try {
      final clientes = await ApiService.getCashierClients();
      if (mounted) setState(() => _clientes = clientes);
    } on ApiFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _depositar(Map<String, dynamic> cliente) async {
    final amountController = TextEditingController();
    final amount = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Depositar a ${cliente['nombre']}'),
        content: TextField(
          controller: amountController,
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
              final value = double.tryParse(amountController.text.trim().replaceAll(',', '.'));
              if (value == null || value <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Ingrese un monto válido')),
                );
                return;
              }
              Navigator.pop(dialogContext, value);
            },
            child: const Text('Depositar'),
          ),
        ],
      ),
    );
    amountController.dispose();
    if (amount == null) return;

    try {
      final result = await ApiService.deposit(
        customerIdentifier: cliente['cedula'].toString(),
        amount: amount,
      );
      if (!mounted) return;
      setState(() {
        cliente['saldo'] = result['saldo'];
      });
      _mostrarMensaje('Depósito de \$${amount.toStringAsFixed(2)} realizado');
    } on ApiFailure catch (error) {
      if (mounted) _mostrarMensaje(error.message, error: true);
    }
  }

  void _mostrarMensaje(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: error ? Colors.red.shade700 : null),
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

  @override
  Widget build(BuildContext context) {
    final branch = widget.usuario['sucursal']?.toString() ?? '';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel de cajero'),
        actions: [
          IconButton(
            onPressed: _cerrarSesion,
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.usuario['nombre']?.toString() ?? 'Cajero', style: Theme.of(context).textTheme.titleLarge),
                if (branch.isNotEmpty) Text(branch),
                const SizedBox(height: 8),
                const Text('Operación autorizada: depósitos a clientes'),
              ],
            ),
          ),
          Expanded(
            child: _cargando
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!))
                    : _clientes.isEmpty
                        ? const Center(child: Text('No hay clientes registrados'))
                        : RefreshIndicator(
                            onRefresh: _cargarClientes,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                              itemCount: _clientes.length,
                              itemBuilder: (context, index) {
                                final cliente = _clientes[index];
                                final photo = cliente['fotoUrl']?.toString() ?? '';
                                final balance = (cliente['saldo'] as num?)?.toDouble() ?? 0;
                                return Card(
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
                                      child: photo.isEmpty ? const Icon(Icons.person) : null,
                                    ),
                                    title: Text(cliente['nombre']?.toString() ?? 'Cliente'),
                                    subtitle: Text(
                                      'Cédula: ${cliente['cedula']} · Saldo: \$${balance.toStringAsFixed(2)}',
                                    ),
                                    trailing: IconButton.filledTonal(
                                      onPressed: () => _depositar(cliente),
                                      tooltip: 'Realizar depósito',
                                      icon: const Icon(Icons.add_card),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}
