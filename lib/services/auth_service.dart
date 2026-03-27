import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  // ── Instancias singleton (se crean una sola vez en toda la app) ────────────
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // ── Stream del estado de sesión (úsalo en main.dart con StreamBuilder) ────
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  // ── Email & Password ───────────────────────────────────────────────────────

  /// Login con email y contraseña.
  /// Lanza [FirebaseAuthException] en caso de error — la UI lo captura.
  Future<UserCredential> loginWithEmail(String email, String password) async {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  /// Registro con email, contraseña y nombre de usuario.
  Future<UserCredential> registerWithEmail(
    String email,
    String password,
    String username,
  ) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    // Guarda el nombre de usuario en el perfil de Firebase Auth
    await credential.user?.updateDisplayName(username);

    return credential;
  }

  // ── Google Sign-In ─────────────────────────────────────────────────────────

  /// Flujo:
  /// 1. Abre el selector de cuenta de Google (GoogleSignIn)
  /// 2. Obtiene los tokens de autenticación
  /// 3. Los convierte en credencial de Firebase
  /// 4. Inicia sesión en Firebase con esa credencial
  ///
  /// Retorna null si el usuario canceló el flujo (sin tirar error).
  Future<UserCredential?> signInWithGoogle() async {
    // Paso 1: Selector de cuenta Google
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

    // Usuario canceló → salimos sin error
    if (googleUser == null) return null;

    // Paso 2: Obtener tokens
    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;

    // Paso 3: Crear credencial de Firebase
    final AuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    // Paso 4: Login en Firebase
    return _auth.signInWithCredential(credential);
  }

  // ── Cierre de sesión ───────────────────────────────────────────────────────

  Future<void> signOut() async {
    await Future.wait([
      _auth.signOut(),
      _googleSignIn.signOut(), // También cierra la sesión de Google
    ]);
  }

  // ── Helpers opcionales ─────────────────────────────────────────────────────

  /// Envía email de recuperación de contraseña
  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // ── Ejemplo: guardar usuario en Firestore (descomenta si lo necesitas) ─────
  // Future<void> _saveUserToFirestore(User user, String username) async {
  //   await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
  //     'uid': user.uid,
  //     'username': username,
  //     'email': user.email,
  //     'createdAt': FieldValue.serverTimestamp(),
  //   }, SetOptions(merge: true)); // merge:true evita sobreescribir si ya existe
  // }
}
