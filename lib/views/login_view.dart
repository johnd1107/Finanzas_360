import 'package:flutter/material.dart';
import '../features/admin_screen.dart';
import '../features/cashier_screen.dart';
import '../features/profile_screen.dart';
import '../services/api_service.dart';
import 'register_view.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _formKey = GlobalKey<FormState>();
  final _usuarioController = TextEditingController();
  final _claveController = TextEditingController();
  bool _ingresando = false;

  @override
  void dispose() {
    _usuarioController.dispose();
    _claveController.dispose();
    super.dispose();
  }

  Future<void> _ingresar() async {
    if (_ingresando || !_formKey.currentState!.validate()) return;
    setState(() => _ingresando = true);
    try {
      final usuario = await ApiService.login(
        identifier: _usuarioController.text.trim(),
        password: _claveController.text,
      );
      if (!mounted) return;
      final pantalla = switch (usuario['rol']) {
        'administrador' => const AdminScreen(),
        'cajero' => CashierScreen(usuario: usuario),
        _ => ProfileScreen(usuario: usuario),
      };
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => pantalla),
      );
    } on ApiFailure catch (error) {
      _mostrarError(error.message);
    } finally {
      if (mounted) setState(() => _ingresando = false);
    }
  }

  void _mostrarError(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(texto), backgroundColor: Colors.red.shade700),
    );
  }

  Future<void> _abrirRegistro() async {
    final registrado = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const RegisterView()),
    );
    if (registrado == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registro guardado exitosamente')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Finanzas 360')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const Icon(Icons.account_balance_wallet, size: 64, color: Colors.blueAccent),
              const SizedBox(height: 24),
              TextFormField(
                controller: _usuarioController,
                decoration: const InputDecoration(
                  labelText: 'Cédula / Usuario',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.badge),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Ingrese usuario o cédula';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _claveController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Contraseña',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
                validator: (value) {
                  final esAdministrador = _usuarioController.text.trim().toLowerCase() == 'admin' ||
                      _usuarioController.text.trim().toLowerCase() == 'administrador';
                  if (value == null || (value.length < 10 && !esAdministrador)) {
                    return 'La contraseña debe tener al menos 10 caracteres';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                  onPressed: _ingresando ? null : _ingresar,
                  child: _ingresando
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('INGRESAR AL SISTEMA', style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _abrirRegistro,
                child: const Text('¿No tienes cuenta? Regístrate aquí'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
