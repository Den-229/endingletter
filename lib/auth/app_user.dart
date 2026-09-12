/// Utilisateur courant (Firebase Auth + rôle hydraté depuis Firestore).
class AppUser {
  const AppUser({
    required this.uid,
    required this.email,
    this.role = '',
  });

  final String uid;
  final String email;
  final String role;

  /// Vrai si le rôle hydraté est 'admin'.
  bool get isAdmin => role == 'admin';

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'email': email,
        'role': role,
      };

  @override
  String toString() =>
      'AppUser(uid: $uid, email: $email, role: $role)';
}