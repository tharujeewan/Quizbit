import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthState extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  String? _userName;
  String? _lastErrorMessage;
  // Whitelist of admin emails. Replace with your admin emails.
  static const Set<String> _adminEmails = {
    'admin@example.com',
    'admin@gmail.com',
    'admin@quizbit.com', // Test admin email
    'test@admin.com', // Alternative test admin email
    // Add your actual admin emails here
  };

  bool get isAuthenticated => _auth.currentUser != null;
  String? get userName => _userName;
  String? get lastErrorMessage => _lastErrorMessage;
  String? get userEmail => _auth.currentUser?.email;
  bool get isAdmin {
    final email = _auth.currentUser?.email?.toLowerCase();
    if (email == null) return false;
    return _adminEmails.contains(email);
  }

  AuthState() {
    _auth.authStateChanges().listen((user) {
      _userName = _deriveUserName(user);
      notifyListeners();
    });
  }

  Future<void> load() async {
    _userName = _deriveUserName(_auth.currentUser);
    notifyListeners();
  }

  Future<bool> login({required String email, required String password}) async {
    try {
      _lastErrorMessage = null;

      await _auth.signInWithEmailAndPassword(email: email, password: password);
      _userName = _deriveUserName(_auth.currentUser);

      // Try to update Firestore document, but don't fail login if it fails
      try {
        await _ensureFirestoreUserDoc();
      } catch (firestoreError) {
        // Log the error but don't fail the login
        print('Firestore update failed during login: $firestoreError');
      }

      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _lastErrorMessage = _mapAuthErrorToMessage(e);
      notifyListeners();
      return false;
    } catch (e) {
      _lastErrorMessage = 'Unexpected error. Please try again.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> signup({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      _lastErrorMessage = null;

      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credential.user;
      if (user != null && name.trim().isNotEmpty) {
        await user.updateDisplayName(name.trim());
      }
      _userName = _deriveUserName(_auth.currentUser);

      // Try to create Firestore document, but don't fail signup if it fails
      try {
        await _ensureFirestoreUserDoc(displayNameOverride: name.trim());
      } catch (firestoreError) {
        // Log the error but don't fail the signup
        print(
            'Firestore document creation failed during signup: $firestoreError');
      }

      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _lastErrorMessage = _mapAuthErrorToMessage(e);
      notifyListeners();
      return false;
    } catch (e) {
      _lastErrorMessage = 'Unexpected error. Please try again.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> signInWithGoogle() async {
    try {
      _lastErrorMessage = null;

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // The user canceled the sign-in
        _lastErrorMessage = 'Google Sign-In was cancelled.';
        notifyListeners();
        return false;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await _auth.signInWithCredential(credential);
      _userName = _deriveUserName(_auth.currentUser);

      await _ensureFirestoreUserDoc();

      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _lastErrorMessage = _mapAuthErrorToMessage(e);
      notifyListeners();
      return false;
    } catch (e) {
      _lastErrorMessage = 'An error occurred with Google Sign-In.';
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
    _userName = null;
    notifyListeners();
  }

  // Method to check if Firebase is properly connected
  Future<bool> checkFirebaseConnection() async {
    try {
      // Try to access a collection that should exist (users collection)
      await FirebaseFirestore.instance.collection('users').limit(1).get();
      return true;
    } catch (e) {
      // If users collection doesn't exist, try a simple ping
      try {
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          return true;
        });
        return true;
      } catch (e) {
        return false;
      }
    }
  }

  String? _deriveUserName(User? user) {
    if (user == null) return null;
    final displayName = user.displayName;
    if (displayName != null && displayName.trim().isNotEmpty) {
      return displayName.trim();
    }
    final email = user.email;
    if (email != null && email.contains('@')) {
      return email.split('@').first;
    }
    return null;
  }

  String _mapAuthErrorToMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'The email address is badly formatted.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
      case 'wrong-password':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'operation-not-allowed':
        return 'Email/password accounts are not enabled.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'too-many-requests':
        return 'Too many attempts. Try again later.';
      case 'network-request-failed':
        return 'Network error. Check your internet connection.';
      default:
        return e.message ?? 'Authentication failed. Please try again.';
    }
  }

  Future<void> _ensureFirestoreUserDoc({String? displayNameOverride}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final usersCollection = FirebaseFirestore.instance.collection('users');
      final userDocRef = usersCollection.doc(user.uid);
      final displayName = (displayNameOverride?.trim().isNotEmpty == true)
          ? displayNameOverride!.trim()
          : (user.displayName?.trim().isNotEmpty == true
              ? user.displayName!.trim()
              : (user.email ?? '').split('@').first);

      await userDocRef.set({
        'displayName': displayName,
        'email': user.email,
        'createdAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
        'quizzesPlayedCount': FieldValue.increment(0),
      }, SetOptions(merge: true));
    } catch (e) {
      // Re-throw the error with more context
      throw Exception('Failed to update user document in Firestore: $e');
    }
  }
}
