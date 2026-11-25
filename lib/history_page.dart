import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';

import 'session_page.dart' show formatDateTime;

class _Entry {
  const _Entry(this.matiere, this.date, this.present);

  final String matiere;
  final DateTime? date;
  final bool present;
}

/// Écran étudiant : historique de ses présences (présent / absent par séance).
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  late Future<List<_Entry>> _future = _load();

  /// Lit toutes les séances, puis vérifie si l'étudiant a signé chacune.
  Future<List<_Entry>> _load() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final sessions = await FirebaseFirestore.instance
        .collection('sessions')
        .orderBy('createdAt', descending: true)
        .get();

    return Future.wait(
      sessions.docs.map((s) async {
        final mine = await s.reference.collection('attendances').doc(uid).get();
        final data = s.data();
        return _Entry(
          data['matiere'] as String? ?? 'Séance',
          (data['createdAt'] as Timestamp?)?.toDate(),
          mine.exists,
        );
      }),
    );
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() {
      _future = next;
    });
    await next;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bigStyle = Theme.of(context).textTheme.displaySmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: scheme.primary,
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Mes présences')),
      body: FutureBuilder<List<_Entry>>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Erreur : ${snap.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final rows = snap.data;
          if (rows == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final present = rows.where((r) => r.present).length;
          final ratio = rows.isEmpty ? 0.0 : present / rows.length;

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Text('${(ratio * 100).round()} %', style: bigStyle),
                        const SizedBox(height: 4),
                        Text('Présent à $present séance(s) sur ${rows.length}'),
                        const SizedBox(height: 12),
                        LinearProgressIndicator(
                          value: ratio,
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (rows.isEmpty) const Text('Aucune séance pour le moment.'),
                for (final r in rows)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      r.present ? Icons.check_circle : Icons.cancel,
                      color: r.present ? Colors.green : scheme.error,
                    ),
                    title: Text(r.matiere),
                    subtitle: Text(formatDateTime(r.date)),
                    trailing: Text(
                      r.present ? 'Présent' : 'Absent',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: r.present ? Colors.green : scheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
