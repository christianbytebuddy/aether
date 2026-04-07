import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  // ── Email & Password ───────────────────────────────────────────────────────

  Future<UserCredential> loginWithEmail(String email, String password) async {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential> registerWithEmail(
    String email,
    String password,
    String username,
  ) async {
    // 1. Crear en Firebase Auth
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final user = credential.user!;

    // 2. Actualizar displayName en Auth (opcional, pero útil)
    await user.updateDisplayName(username);

    // 3. Guardar perfil completo en Firestore
    await _saveUserToFirestore(user, username: username);

    return credential;
  }

  // ── Google Sign-In ─────────────────────────────────────────────────────────

  Future<UserCredential?> signInWithGoogle() async {
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null;

    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;

    final AuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential = await _auth.signInWithCredential(credential);

    // Solo crea el documento si es la primera vez que entra con Google
    if (userCredential.additionalUserInfo?.isNewUser == true) {
      await _saveUserToFirestore(userCredential.user!);
    }

    return userCredential;
  }

  // ── Cierre de sesión ───────────────────────────────────────────────────────

  Future<void> signOut() async {
    await Future.wait([_auth.signOut(), _googleSignIn.signOut()]);
  }

  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // ── Guardar perfil en Firestore ────────────────────────────────────────────

  Future<void> _saveUserToFirestore(User user, {String? username}) async {
    await _db.collection('users').doc(user.uid).set(
      {
        'uid': user.uid,
        'email': user.email,
        // Para Google: usa el displayName de Google si no hay username
        'username': username ?? user.displayName ?? 'usuario',
        'photoUrl': user.photoURL, // Google lo trae automáticamente
        'createdAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    ); // merge: true protege datos si el doc ya existe
  }
}
