import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref().child('users');

  // Email Sign-Up
  Future<String?> signUpWithEmail({
    required String email,
    required String password,
    required String fullName,
    required String username,
  }) async {
    try {
      final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = userCredential.user?.uid;
      if (uid != null) {
        await _dbRef.child(uid).set({
          'uid': uid,
          'email': email,
          'fullName': fullName,
          'username': username,
        });
      }

      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  // Email Login
  Future<String?> loginWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  // Google Sign-In
  Future<String?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return 'Cancelled by user';

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final uid = userCredential.user?.uid;
      final email = userCredential.user?.email;
      final name = userCredential.user?.displayName;

      if (uid != null && email != null) {
        final userSnapshot = await _dbRef.child(uid).get();
        if (!userSnapshot.exists) {
          await _dbRef.child(uid).set({
            'uid': uid,
            'email': email,
            'fullName': name ?? '',
            'username': name ?? '',
          });
        }
      }

      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // Sign Out
  Future<void> signOut() async {
    await _auth.signOut();
    await GoogleSignIn().signOut();
  }
}
