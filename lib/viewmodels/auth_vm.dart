import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../models/user.dart';

class AuthViewModel with ChangeNotifier {
  final AuthService authService;
  bool _isLoading = false;
  AppUser? _currentUser;
  String? _userRole;
  String? _errorMessage;

  AuthViewModel({required this.authService});

  AppUser? get currentUser => _currentUser;
  String? get userRole => _userRole;
  String? get errorMessage => _errorMessage;

  bool get isLoading => _isLoading;

  Future<void> signIn(String email, String password) async {
    try {
      _isLoading = true;
      notifyListeners();
      
      final user = await authService.signIn(email, password);
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        
        if (!userDoc.exists) throw Exception('User document not found');
        if (userDoc.data() == null) {throw Exception("Les données utilisateur sont nulles !");}
        _currentUser = AppUser.fromFirestore(userDoc.data()!);
        _userRole = userDoc.data()!['role'];
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }


  Future<void> signOut() async {
    await authService.signOut();
    _currentUser = null;
    _userRole = null;
    notifyListeners();
  }

  Stream<AppUser?> get authStateChanges => authService.authStateChanges
      .asyncMap((user) => user != null ? _getUserData(user.uid) : null);

  Future<AppUser?> _getUserData(String uid) async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    return doc.exists ? AppUser.fromFirestore(doc.data()!) : null;
  }

  Future<void> signUp(
    String email, 
    String password,
    String name,
    String role,
  ) async {
    try {
      final user = await authService.signUp(email, password, name, role);
      if (user != null) {
        _currentUser = AppUser(
          uid: user.uid,
          email: user.email ?? '',
          name: name,
          role: role,
        );
        _userRole = role;
      }
    } catch (e) {
      _errorMessage = e.toString();
    }
    notifyListeners();
  }

  // Add this method to update the current user
  Future<void> updateCurrentUser(AppUser? user) async {
    _currentUser = user;
    _userRole = user?.role;
    notifyListeners();
  }

  // Add this method to refresh user data from Firestore
  Future<void> refreshUserData() async {
    if (_currentUser == null) return;
    
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .get();
      
      if (userDoc.exists) {
        await updateCurrentUser(AppUser.fromFirestore(userDoc.data()!));
      }
    } catch (e) {
      debugPrint('Error refreshing user data: $e');
    }
  }


}