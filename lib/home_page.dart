import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';

import 'scan_page.dart';
import 'session_page.dart';

String _randomCode([int length = 10]) {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final rnd = Random.secure();
  return List.generate(length, (_) => chars[rnd.nextInt(chars.length)]).join();
}

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.user});

  final User user;

  Future<void> _newSession(BuildContext context) async {
    final controller = TextEditingController();
    final matiere = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nouvelle séance'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Matière',
            hintText: 'Ex : Développement mobile',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Créer'),
          ),
        ],
      ),
    );
    if (matiere == null || matiere.isEmpty) return;

    final ref = await FirebaseFirestore.instance.collection('sessions').add({
      'profId': user.uid,
      'profEmail': user.email,
      'matiere': matiere,
      'code': _randomCode(),
      'active': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SessionPage(sessionId: ref.id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final doc = FirebaseFirestore.instance.collection('users').doc(user.uid);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: doc.snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data() ?? <String, dynamic>{};
        final isProf = data['role'] == 'prof';

        return Scaffold(
          appBar: AppBar(
            title: const Text('Présence QR'),
            actions: [
              IconButton(
                tooltip: 'Se déconnecter',
                icon: const Icon(Icons.logout),
                onPressed: FirebaseAuth.instance.signOut,
              ),
            ],
          ),
          floatingActionButton: isProf
              ? FloatingActionButton.extended(
                  onPressed: () => _newSession(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Nouvelle séance'),
                )
              : null,
          body: !snap.hasData
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
                  children: [
                    _ProfileCard(user: user, data: data),
                    const SizedBox(height: 24),
                    if (isProf)
                      _SessionsList(profId: user.uid)
                    else
                      const _StudentActions(),
                  ],
                ),
        );
      },
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.user, required this.data});

  final User user;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final role = switch (data['role']) {
      'prof' => 'Professeur',
      'etudiant' => 'Étudiant',
      _ => 'Non défini',
    };

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: scheme.primaryContainer,
              child: Icon(
                Icons.person,
                size: 32,
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.email ?? '',
                    style: Theme.of(context).textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text('ID : ${data['matricule'] ?? '—'}'),
                  const SizedBox(height: 8),
                  Chip(label: Text(role)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

int _byNewest(
  QueryDocumentSnapshot<Map<String, dynamic>> a,
  QueryDocumentSnapshot<Map<String, dynamic>> b,
) {
  final ta = a.data()['createdAt'] as Timestamp?;
  final tb = b.data()['createdAt'] as Timestamp?;
  if (ta == null && tb == null) return 0;
  if (ta == null) return -1; // écriture en cours = la plus récente
  if (tb == null) return 1;
  return tb.compareTo(ta);
}

class _SessionsList extends StatelessWidget {
  const _SessionsList({required this.profId});

  final String profId;

  @override
  Widget build(BuildContext context) {
    final query = FirebaseFirestore.instance
        .collection('sessions')
        .where('profId', isEqualTo: profId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Mes séances', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: query.snapshots(),
          builder: (context, snap) {
            if (snap.hasError) return Text('Erreur : ${snap.error}');
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final docs = snap.data!.docs.toList()..sort(_byNewest);
            if (docs.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('Aucune séance pour le moment.')),
              );
            }
            return Column(
              children: [for (final d in docs) _SessionTile(doc: d)],
            );
          },
        ),
      ],
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.doc});

  final QueryDocumentSnapshot<Map<String, dynamic>> doc;

  @override
  Widget build(BuildContext context) {
    final data = doc.data();
    final active = data['active'] == true;
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(active ? Icons.qr_code_2 : Icons.check_circle_outline),
        title: Text(data['matiere'] as String? ?? ''),
        subtitle: Text(
          '${formatDateTime(createdAt)} • ${active ? 'En cours' : 'Terminée'}',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => SessionPage(sessionId: doc.id)),
        ),
      ),
    );
  }
}

class _StudentActions extends StatelessWidget {
  const _StudentActions();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.qr_code_scanner,
              size: 56,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            const Text(
              'Scanne le QR code affiché par ton professeur pour signer ta présence.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ScanPage()),
              ),
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scanner un QR code'),
            ),
          ],
        ),
      ),
    );
  }
}
