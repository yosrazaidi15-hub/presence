import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Format simple jj/mm/aaaa hh:mm (sans package supplémentaire).
String formatDateTime(DateTime? d) {
  if (d == null) return '...';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
}

/// Écran d'une séance : QR code à montrer aux étudiants + liste des présents.
class SessionPage extends StatelessWidget {
  const SessionPage({super.key, required this.sessionId});

  final String sessionId;

  Future<void> _end(
    BuildContext context,
    DocumentReference<Map<String, dynamic>> ref,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Terminer la séance ?'),
        content: const Text("Le QR code ne sera plus valide."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Terminer'),
          ),
        ],
      ),
    );
    if (ok == true) await ref.update({'active': false});
  }

  @override
  Widget build(BuildContext context) {
    final ref =
        FirebaseFirestore.instance.collection('sessions').doc(sessionId);
    final scheme = Theme.of(context).colorScheme;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: ref.snapshots(),
      builder: (context, snap) {
        if (snap.hasData && !snap.data!.exists) {
          return Scaffold(
            appBar: AppBar(title: const Text('Séance')),
            body: const Center(child: Text('Séance introuvable.')),
          );
        }
        final data = snap.data?.data();
        if (data == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Séance')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final active = data['active'] == true;
        final matiere = data['matiere'] as String? ?? '';
        final code = data['code'] as String? ?? '';
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

        return Scaffold(
          appBar: AppBar(title: Text(matiere)),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      if (active) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: QrImageView(
                            data: 'PQR:$sessionId:$code',
                            size: 240,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Les étudiants scannent ce QR code pour signer leur présence.',
                          textAlign: TextAlign.center,
                        ),
                      ] else ...[
                        Icon(Icons.lock_outline, size: 64, color: scheme.outline),
                        const SizedBox(height: 12),
                        const Text(
                          "Séance terminée : le QR code n'est plus valide.",
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        formatDateTime(createdAt),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (active)
                FilledButton.tonalIcon(
                  onPressed: () => _end(context, ref),
                  icon: const Icon(Icons.stop_circle_outlined),
                  label: const Text('Terminer la séance'),
                ),
              const SizedBox(height: 24),
              _Attendees(sessionId: sessionId),
            ],
          ),
        );
      },
    );
  }
}

/// Liste en direct des étudiants qui ont signé leur présence.
class _Attendees extends StatelessWidget {
  const _Attendees({required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection('sessions')
        .doc(sessionId)
        .collection('attendances')
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        final docs = snap.data?.docs;
        final count = docs?.length ?? 0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Présents ($count)',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            if (docs == null || docs.isEmpty)
              const Text("Personne n'a encore signé.")
            else
              for (final d in docs)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.person_outline),
                  title: Text('${d.data()['email'] ?? d.id}'),
                  subtitle: Text('ID : ${d.data()['matricule'] ?? '—'}'),
                ),
          ],
        );
      },
    );
  }
}
