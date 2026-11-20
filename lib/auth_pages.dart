import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';

InputDecoration _decoration(String label, IconData icon, {Widget? suffix}) {
  return InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon),
    suffixIcon: suffix,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
  );
}

void _toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

/// Écran de connexion / création de compte.
class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _matricule = TextEditingController();
  bool _register = false;
  bool _hidePassword = true;
  bool _loading = false;
  String _role = 'etudiant';

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _matricule.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text;
    final matricule = _matricule.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _toast(context, 'Saisis ton email et ton mot de passe');
      return;
    }
    if (_register && matricule.isEmpty) {
      _toast(context, 'Saisis ton ID (matricule)');
      return;
    }

    setState(() => _loading = true);
    try {
      final auth = FirebaseAuth.instance;
      if (_register) {
        final cred = await auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        final user = cred.user!;
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'email': email,
          'matricule': matricule,
          'role': _role,
          'createdAt': FieldValue.serverTimestamp(),
        });
        await user.sendEmailVerification();
      } else {
        await auth.signInWithEmailAndPassword(email: email, password: password);
      }
    } on FirebaseException catch (e) {
      if (mounted) _toast(context, e.message ?? e.code);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      _toast(context, 'Saisis ton email puis reclique sur le lien');
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        _toast(context, 'Email de réinitialisation envoyé. Pense aux spams.');
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) _toast(context, e.message ?? e.code);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: scheme.primaryContainer,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(Icons.qr_code_2, size: 64, color: scheme.primary),
                      const SizedBox(height: 8),
                      Text(
                        'Présence QR',
                        textAlign: TextAlign.center,
                        style: textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _register
                            ? 'Crée ton compte'
                            : 'Connecte-toi pour continuer',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: _decoration('Email', Icons.email_outlined),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _password,
                        obscureText: _hidePassword,
                        decoration: _decoration(
                          'Mot de passe',
                          Icons.lock_outline,
                          suffix: IconButton(
                            icon: Icon(
                              _hidePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () =>
                                setState(() => _hidePassword = !_hidePassword),
                          ),
                        ),
                      ),
                      if (_register) ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: _matricule,
                          decoration: _decoration(
                            'ID (matricule)',
                            Icons.badge_outlined,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(
                              value: 'etudiant',
                              label: Text('Étudiant'),
                              icon: Icon(Icons.school_outlined),
                            ),
                            ButtonSegment(
                              value: 'prof',
                              label: Text('Prof'),
                              icon: Icon(Icons.person_outline),
                            ),
                          ],
                          selected: {_role},
                          onSelectionChanged: (s) =>
                              setState(() => _role = s.first),
                        ),
                      ],
                      if (!_register)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _forgotPassword,
                            child: const Text('Mot de passe oublié ?'),
                          ),
                        ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _loading ? null : _submit,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                        child: _loading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                _register ? 'Créer mon compte' : 'Se connecter',
                              ),
                      ),
                      TextButton(
                        onPressed: _loading
                            ? null
                            : () => setState(() => _register = !_register),
                        child: Text(
                          _register
                              ? "J'ai déjà un compte"
                              : 'Pas de compte ? Créer un compte',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Écran affiché tant que l'email n'est pas vérifié.
class VerifyEmailPage extends StatelessWidget {
  const VerifyEmailPage({super.key, required this.onChecked});

  final VoidCallback onChecked;

  Future<void> _check(BuildContext context) async {
    await FirebaseAuth.instance.currentUser?.reload();
    onChecked();
    if (!context.mounted) return;
    final verified = FirebaseAuth.instance.currentUser?.emailVerified ?? false;
    if (!verified) {
      _toast(context, 'Email pas encore vérifié. Clique sur le lien reçu.');
    }
  }

  Future<void> _resend(BuildContext context) async {
    try {
      await FirebaseAuth.instance.currentUser?.sendEmailVerification();
      if (context.mounted) {
        _toast(context, 'Email envoyé. Pense à vérifier les spams.');
      }
    } on FirebaseAuthException catch (e) {
      if (context.mounted) _toast(context, e.message ?? e.code);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.mark_email_unread_outlined,
                  size: 72,
                  color: scheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Vérifie ton email',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'On a envoyé un lien à ${user?.email}. '
                  'Clique dessus (regarde aussi les spams), puis reviens ici.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => _check(context),
                  child: const Text("J'ai vérifié mon email"),
                ),
                TextButton(
                  onPressed: () => _resend(context),
                  child: const Text("Renvoyer l'email"),
                ),
                TextButton(
                  onPressed: FirebaseAuth.instance.signOut,
                  child: const Text('Se déconnecter'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
