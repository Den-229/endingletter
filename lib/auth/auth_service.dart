import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';

import 'app_user.dart';

/// Wrapper autour de FirebaseAuth + hydratation du rôle depuis Firestore.
///
/// Cycle de vie :
///   1. `init()` est appelé au démarrage de l'app (peut échouer si offline
///      ou si Firebase n'est pas configuré ; on log un warning et on continue).
///   2. `authStateChanges` expose un [Stream<AppUser?>] que la UI peut
///      écouter pour afficher/masquer les boutons admin.
///   3. `signIn` ouvre une session Firebase puis lit `users/{uid}.role` dans
///      Firestore. Si le doc est absent ou que `role != "admin"`, l'utilisateur
///      est connecté mais `isAdmin` reste false.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final fb.FirebaseAuth _auth = fb.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  AppUser? _current;
  bool _initialized = false;

  AppUser? get currentUser => _current;
  bool get isSignedIn => _current != null;
  bool get isAdmin => _current?.isAdmin ?? false;

  /// Stream qui émet à chaque connexion / déconnexion + hydratation du rôle.
  Stream<AppUser?> get authStateChanges {
    return _auth.authStateChanges().asyncMap(_hydrate);
  }

  /// Initialisation paresseuse : on s'abonne à `authStateChanges` pour mettre
  /// à jour le cache interne. Renvoie l'état actuel (signIn immédiat si une
  /// session est restaurée).
  Future<AppUser?> init() async {
    if (_initialized) return _current;
    _initialized = true;
    final user = _auth.currentUser;
    if (user != null) {
      _current = await _hydrate(user);
    }
    // Souscrit aux changements pour les futures sessions.
    authStateChanges.listen((u) {
      _current = u;
    }, onError: (Object e) {
      if (kDebugMode) debugPrint('⚠️ AuthState error: $e');
    });
    return _current;
  }

  Future<AppUser> signIn(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = cred.user;
    if (user == null) {
      throw StateError('Connexion échouée : utilisateur null');
    }
    final appUser = await _hydrate(user);
    if (appUser == null) {
      throw StateError('Hydratation du rôle a échoué');
    }
    _current = appUser;
    return appUser;
  }

  Future<void> signOut() async {
    await _auth.signOut();
    _current = null;
  }

  Future<AppUser?> _hydrate(fb.User? fbUser) async {
    if (fbUser == null) return null;
    String role = '';
    try {
      final doc =
          await _firestore.collection('users').doc(fbUser.uid).get();
      if (doc.exists) {
        final data = doc.data() ?? const {};
        role = (data['role'] as String?) ?? '';
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Lecture users/${fbUser.uid} échouée: $e');
      }
    }
    return AppUser(
      uid: fbUser.uid,
      email: fbUser.email ?? '',
      role: role,
    );
  }
}