import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:aether/services/auth_service.dart';
import 'package:aether/utils/validators.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  // ── Formulario ──────────────────────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPassController = TextEditingController();

  // ── Estado UI ────────────────────────────────────────────────────────────────
  bool _isLoading = false;
  bool _obscurePass = true;
  bool _obscureConfirm = true;

  // ── Servicio ─────────────────────────────────────────────────────────────────
  final _authService = AuthService();

  // ── Colores constantes ────────────────────────────────────────────────────────
  static const _bgColor = Color(0xFF0B0F1A);
  static const _cardColor = Color(0xFF141726);
  static const _fieldColor = Color(0xFF1C1F2E);
  static const _iconBgColor = Color(0xFF1C1F2E);
  static const _accentColor = Color(0xFF7B6EF6);

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPassController.dispose();
    super.dispose();
  }

  // ── Lógica ────────────────────────────────────────────────────────────────────

  Future<void> _handleRegister() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      await _authService.registerWithEmail(
        _emailController.text.trim(),
        _passwordController.text,
        _usernameController.text.trim(),
      );
      if (mounted) Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      _showError(_firebaseMessage(e.code));
    } catch (_) {
      _showError('Ocurrió un error inesperado. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Google Register ───────────────────────────────────────────────────────────
  Future<void> _handleGoogleRegister() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      await _authService.signInWithGoogle();
      if (mounted) Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      _showError(_firebaseMessage(e.code));
    } catch (_) {
      _showError('No se pudo continuar con Google.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _firebaseMessage(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'Este email ya está registrado.';
      case 'invalid-email':
        return 'El formato del email no es válido.';
      case 'weak-password':
        return 'La contraseña es demasiado débil.';
      case 'network-request-failed':
        return 'Sin conexión a internet.';
      case 'operation-not-allowed':
        return 'Registro con email no habilitado.';
      default:
        return 'Error al crear la cuenta. Intenta de nuevo.';
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 30),
                  _buildCard(),
                  const SizedBox(height: 20),
                  _buildLoginLink(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Widgets ───────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _iconBgColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.auto_awesome, color: Colors.white),
        ),
        const SizedBox(height: 20),
        const Text(
          'Crear cuenta',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Únete a Aether',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          // Username
          TextFormField(
            controller: _usernameController,
            style: const TextStyle(color: Colors.white),
            textInputAction: TextInputAction.next,
            enabled: !_isLoading,
            validator: Validators.username,
            decoration: _inputDecoration('Nombre de usuario', Icons.person),
          ),

          const SizedBox(height: 12),

          // Email
          TextFormField(
            controller: _emailController,
            style: const TextStyle(color: Colors.white),
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            enabled: !_isLoading,
            validator: Validators.email,
            decoration: _inputDecoration('Email', Icons.email),
          ),

          const SizedBox(height: 12),

          // Contraseña
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePass,
            style: const TextStyle(color: Colors.white),
            textInputAction: TextInputAction.next,
            enabled: !_isLoading,
            validator: Validators.registerPassword,
            onChanged: (_) {
              if (_confirmPassController.text.isNotEmpty) {
                _formKey.currentState?.validate();
              }
            },
            decoration: _inputDecoration(
              'Contraseña',
              Icons.lock,
              suffix: _toggleVisibilityButton(
                visible: _obscurePass,
                onTap: () => setState(() => _obscurePass = !_obscurePass),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Confirmar contraseña
          TextFormField(
            controller: _confirmPassController,
            obscureText: _obscureConfirm,
            style: const TextStyle(color: Colors.white),
            textInputAction: TextInputAction.done,
            enabled: !_isLoading,
            validator: Validators.confirmPassword(_passwordController.text),
            onFieldSubmitted: (_) => _handleRegister(),
            decoration: _inputDecoration(
              'Confirmar contraseña',
              Icons.lock_outline,
              suffix: _toggleVisibilityButton(
                visible: _obscureConfirm,
                onTap: () => setState(() => _obscureConfirm = !_obscureConfirm),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Barra de fuerza de contraseña
          _buildPasswordStrength(),

          const SizedBox(height: 16),

          // Botón principal — Crear cuenta
          SizedBox(
            width: double.infinity,
            height: 45,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleRegister,
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentColor,
                disabledBackgroundColor: _accentColor.withOpacity(0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Crear cuenta',
                      style: TextStyle(color: Colors.white),
                    ),
            ),
          ),

          const SizedBox(height: 12),

          // Divisor "o"
          Row(
            children: const [
              Expanded(child: Divider(color: Colors.white24)),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('o', style: TextStyle(color: Colors.white38)),
              ),
              Expanded(child: Divider(color: Colors.white24)),
            ],
          ),

          const SizedBox(height: 12),

          // Botón Google
          SizedBox(
            width: double.infinity,
            height: 45,
            child: OutlinedButton.icon(
              onPressed: _isLoading ? null : _handleGoogleRegister,
              icon: _isLoading
                  ? const SizedBox.shrink()
                  : Image.asset(
                      'assets/images/google_logo.png',
                      height: 20,
                      width: 20,
                    ),
              label: const Text(
                'Continuar con Google',
                style: TextStyle(color: Colors.white70),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordStrength() {
    final pass = _passwordController.text;
    if (pass.isEmpty) return const SizedBox.shrink();

    int strength = 0;
    if (pass.length >= 8) strength++;
    if (pass.contains(RegExp(r'[A-Z]'))) strength++;
    if (pass.contains(RegExp(r'[0-9]'))) strength++;
    if (pass.contains(RegExp(r'[!@#\$%^&*]'))) strength++;

    final colors = [
      Colors.redAccent,
      Colors.orange,
      Colors.yellow,
      Colors.greenAccent,
    ];
    final labels = ['Muy débil', 'Débil', 'Buena', 'Fuerte'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(4, (i) {
            return Expanded(
              child: Container(
                margin: const EdgeInsets.only(right: 4),
                height: 4,
                decoration: BoxDecoration(
                  color: i < strength ? colors[strength - 1] : Colors.white12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 4),
        Text(
          labels[strength > 0 ? strength - 1 : 0],
          style: TextStyle(
            color: colors[strength > 0 ? strength - 1 : 0],
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          '¿Ya tienes cuenta? ',
          style: TextStyle(color: Colors.white54),
        ),
        GestureDetector(
          onTap: _isLoading ? null : () => Navigator.pop(context),
          child: const Text(
            'Inicia sesión',
            style: TextStyle(color: _accentColor, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  Widget _toggleVisibilityButton({
    required bool visible,
    required VoidCallback onTap,
  }) {
    return IconButton(
      icon: Icon(
        visible ? Icons.visibility_off : Icons.visibility,
        color: Colors.white38,
        size: 20,
      ),
      onPressed: onTap,
    );
  }

  InputDecoration _inputDecoration(
    String hint,
    IconData icon, {
    Widget? suffix,
  }) {
    return InputDecoration(
      prefixIcon: Icon(icon, color: Colors.white38),
      suffixIcon: suffix,
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white38),
      filled: true,
      fillColor: _fieldColor,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _accentColor, width: 1),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1),
      ),
      errorStyle: const TextStyle(color: Colors.redAccent, fontSize: 11),
    );
  }
}
