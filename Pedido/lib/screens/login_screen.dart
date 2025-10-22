import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final res = await AuthService().login(
        username: _userCtrl.text.trim(),
        password: _passCtrl.text,
      );
      if (res['success'] == true) {
        if (!mounted) return;
        context.go('/painel');
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message']?.toString() ?? 'Falha no login'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    Text(
                      'Entrar no painel',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _userCtrl,
                      decoration: const InputDecoration(labelText: 'Usuário'),
                      validator:
                          (v) =>
                              (v == null || v.isEmpty)
                                  ? 'Informe o usuário'
                                  : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passCtrl,
                      decoration: const InputDecoration(labelText: 'Senha'),
                      obscureText: true,
                      validator:
                          (v) =>
                              (v == null || v.isEmpty)
                                  ? 'Informe a senha'
                                  : null,
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _loading ? null : _submit,
                      child:
                          _loading
                              ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : const Text('Entrar'),
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
