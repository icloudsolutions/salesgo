import 'package:cloud_firestore/cloud_firestore.dart' show FieldValue, FirebaseFirestore;
import 'package:firebase_auth/firebase_auth.dart';

abstract class AuthService {
  Future<User?> signIn(String email, String password);
  Future<User?> signUp(String email, String password, String name, String role);
  Future<void> signOut();
  Stream<User?> get authStateChanges;
}

class FirebaseAuthService implements AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Future<User?> signIn(String email, String password) async {
    try {
      // Corrected: Store the UserCredential properly
      final UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      // Return the User object from UserCredential
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    } catch (e) {
      throw Exception('Login error: $e');
    }
  }

  String _handleAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'invalid-email':
        return 'Invalid email format.';
      default:
        return 'Login failed: ${e.message}';
    }
  }

    @override
  Future<User?> signUp(String email, String password,String name, String role) async {
    try {
      final UserCredential userCredential = 
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Create user document in Firestore
      await _createUserDocument(userCredential.user!, name, role);
      
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    }
  }

  Future<void> _createUserDocument(User user, String name, String role) async {
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'email': user.email,
      'role': role,
      'name': name,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }


  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Stream<User?> get authStateChanges => _auth.authStateChanges();

Future<void> resetPassword(String email) async {
  await _auth.sendPasswordResetEmail(email: email);
}


}