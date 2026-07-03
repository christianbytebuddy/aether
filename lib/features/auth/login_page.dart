import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:aether/services/auth_service.dart';
import 'package:aether/utils/validators.dart';
import 'package:aether/features/auth/register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // ── Formulario ──────────────────────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // ── Estado UI ────────────────────────────────────────────────────────────────
  bool _isLoading = false; // Bloquea envíos duplicados
  bool _obscurePassword = true; // Toggle ver/ocultar contraseña

  // ── Servicio (singleton liviano no se recrea en cada rebuild) ───────────
  final _authService = AuthService();

  // ── Colores constantes (evita reconstruir objetos Color en cada frame) ────
  static const _bgColor = Color.fromRGBO(14, 16, 23, 1);
  static const _cardColor = Color.fromRGBO(21, 23, 32, 1);
  static const _fieldColor = Color.fromRGBO(31, 33, 43, 1);
  static const _iconBgColor = Color.fromRGBO(38, 37, 69, 1);
  static const _accentColor = Color(0xFF7B6EF6);

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ── Lógica separada del build ─────────────────────────────────────────────
  Future<void> _handleEmailLogin() async {
    // 1. Valida el formulario completo
    if (!_formKey.currentState!.validate()) return;

    // 2. Evita llamadas duplicadas
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      await _authService.loginWithEmail(
        _emailController.text.trim(),
        _passwordController.text,
      );
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/splash', (route) => false);
      }
    } on FirebaseAuthException catch (e) {
      _showError(_firebaseMessage(e.code));
    } catch (_) {
      _showError('Ocurrió un error inesperado. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleLogin() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      await _authService.signInWithGoogle();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/splash', (route) => false);
      }
    } on FirebaseAuthException catch (e) {
      _showError(_firebaseMessage(e.code));
    } catch (_) {
      _showError('No se pudo iniciar sesión con Google.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Traduce códigos de Firebase a mensajes humanos
  String _firebaseMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No existe una cuenta con este email.';
      case 'invalid-credential':
        return 'Email o contraseña incorrectos.';
      case 'invalid-email':
        return 'El formato del email no es válido.';
      case 'user-disabled':
        return 'Esta cuenta ha sido deshabilitada.';
      case 'too-many-requests':
        return 'Demasiados intentos. Espera unos minutos.';
      case 'network-request-failed':
        return 'Sin conexión a internet.';
      default:
        return 'Error de autenticación. Intenta de nuevo.';
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

  // ── Build ─────────────────────────────────────────────────────────────────
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
                  _buildRegisterLink(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Widgets extraídos (menos trabajo para el GPU del J2) ──────────────────

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _iconBgColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.auto_awesome, color: _accentColor),
        ),
        const SizedBox(height: 20),
        const Text(
          'Bienvenido a Aether',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Tu universo musical',
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
            obscureText: _obscurePassword,
            style: const TextStyle(color: Colors.white),
            textInputAction: TextInputAction.done,
            enabled: !_isLoading,
            validator: Validators.loginPassword,
            onFieldSubmitted: (_) => _handleEmailLogin(),
            decoration: _inputDecoration(
              'Contraseña',
              Icons.lock,
              suffix: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: Colors.white38,
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Botón principal
          _buildPrimaryButton(
            label: 'Iniciar Sesión',
            onPressed: _handleEmailLogin,
          ),

          const SizedBox(height: 12),

          // Divisor
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
          _buildGoogleButton(),
        ],
      ),
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 45,
      child: ElevatedButton(
        onPressed: _isLoading ? null : onPressed,
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
            : Text(label, style: const TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildGoogleButton() {
    return SizedBox(
      width: double.infinity,
      height: 45,
      child: OutlinedButton.icon(
        onPressed: _isLoading ? null : _handleGoogleLogin,
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
    );
  }

  Widget _buildRegisterLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          '¿No tienes cuenta? ',
          style: TextStyle(color: Colors.white54),
        ),
        GestureDetector(
          onTap: _isLoading
              ? null
              : () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RegisterPage()),
                ),
          child: const Text(
            'Regístrate',
            style: TextStyle(color: _accentColor, fontWeight: FontWeight.w500),
          ),
        ),
      ],
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
      // Borde normal
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      // Borde con foco (acento sutil)
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _accentColor, width: 1),
      ),
      // Borde de error
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
