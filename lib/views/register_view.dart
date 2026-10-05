import 'package:flutter/material.dart';
import '../core/config/app_config.dart';
import '../services/api_service.dart';

class RegisterView extends StatefulWidget {
  const RegisterView({super.key});

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController(
    text: AppConfig.testMode ? AppConfig.testPassword : '',
  );
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ApiService.register(
        name: _nameController.text.trim(),
        identifier: _identifierController.text.trim(),
        password: _passwordController.text,
      );
      if (mounted) Navigator.pop(context, true);
    } on ApiFailure catch (error) {
      _showError(error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String? _validateRequired(String? value, String label) {
    if (value == null || value.trim().isEmpty) return 'Ingrese $label';
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.length < 10) {
      return 'La contraseña debe tener al menos 10 caracteres';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Registro', style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Nombre Completo',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (value) => _validateRequired(value, 'su nombre'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _identifierController,
                      decoration: const InputDecoration(
                        labelText: 'Cédula / Usuario',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                      validator: (value) {
                        final identifier = value?.trim() ?? '';
                        if (AppConfig.testMode && !RegExp(r'^\d{10}$').hasMatch(identifier)) {
                          return 'Ingrese 10 dígitos; no se valida la cédula';
                        }
                        return _validateRequired(value, 'su cédula o usuario');
                      },
                    ),
                    const SizedBox(height: 16),
                    if (AppConfig.testMode)
                      TextFormField(
                        controller: _passwordController,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Clave común de pruebas',
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                      )
                    else
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Contraseña',
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                        validator: _validatePassword,
                      ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _saving ? null : _register,
                      child: _saving
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('REGISTRARME'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}