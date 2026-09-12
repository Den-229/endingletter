import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'auth_service.dart';

/// Écran de connexion admin (email + password).
/// Affiche soit le formulaire, soit l'état connecté avec bouton déconnexion.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Email et mot de passe requis');
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final user = await AuthService.instance.signIn(email, password);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(user.isAdmin
              ? 'Bienvenue, admin ${user.email} !'
              : 'Connecté en tant qu\'utilisateur standard'),
          backgroundColor: user.isAdmin ? Colors.green : Colors.blueGrey,
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _error = _humanizeError(e.toString());
        _isLoading = false;
      });
    }
  }

  String _humanizeError(String raw) {
    if (raw.contains('user-not-found') ||
        raw.contains('wrong-password') ||
        raw.contains('invalid-credential')) {
      return 'Email ou mot de passe incorrect.';
    }
    if (raw.contains('network')) {
      return 'Pas de connexion Internet.';
    }
    return 'Erreur : $raw';
  }

  Future<void> _signOut() async {
    await AuthService.instance.signOut();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Déconnecté')),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Administration'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: user == null ? _buildForm(theme) : _buildSignedIn(user, theme),
        ),
      ),
    );
  }

  Widget _buildForm(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        Icon(Icons.admin_panel_settings,
                size: 80, color: theme.colorScheme.primary)
            .animate()
            .scale(duration: 600.ms, curve: Curves.easeOutBack),
        const SizedBox(height: 24),
        Text(
          'Connexion Admin',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 32),
        TextField(
          controller: _emailCtrl,
          enabled: !_isLoading,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          decoration: const InputDecoration(
            labelText: 'Email',
            prefixIcon: Icon(Icons.email_outlined),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _passwordCtrl,
          enabled: !_isLoading,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Mot de passe',
            prefixIcon: Icon(Icons.lock_outline),
            border: OutlineInputBorder(),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.colorScheme.error),
          ).animate().shake(duration: 400.ms),
        ],
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('SE CONNECTER',
                  style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 24),
        Text(
          'Seuls les administrateurs peuvent publier la wordlist.\n'
          'Le premier admin doit être créé depuis la console Firebase.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
        ),
      ],
    );
  }

  Widget _buildSignedIn(dynamic user, ThemeData theme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.verified_user,
                size: 80, color: theme.colorScheme.primary)
            .animate()
            .scale(duration: 500.ms, curve: Curves.easeOutBack),
        const SizedBox(height: 24),
        Text(
          'Connecté',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          user.email,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
          decoration: BoxDecoration(
            color: user.isAdmin
                ? Colors.green.withValues(alpha: 0.2)
                : Colors.orange.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: user.isAdmin ? Colors.green : Colors.orange,
              width: 2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(user.isAdmin ? Icons.admin_panel_settings : Icons.person,
                  color: user.isAdmin ? Colors.green : Colors.orange),
              const SizedBox(width: 8),
              Text(
                user.isAdmin ? 'ADMINISTRATEUR' : 'UTILISATEUR STANDARD',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: user.isAdmin ? Colors.green : Colors.orange,
                ),
              ),
            ],
          ),
        ).animate().fade().scale(),
        const SizedBox(height: 32),
        OutlinedButton.icon(
          onPressed: _signOut,
          icon: const Icon(Icons.logout),
          label: const Text('SE DÉCONNECTER'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }
}