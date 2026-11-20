import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class _ScanResult {
  const _ScanResult(this.ok, this.message);

  final bool ok;
  final String message;
}

/// Écran de scan (étudiant) : lit le QR code de la séance et enregistre la présence.
class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  bool _busy = false;

  /// Vérifie le QR (format PQR:idSéance:code) puis enregistre la présence.
  Future<_ScanResult> _sign(String value) async {
    final parts = value.split(':');
    if (parts.length != 3 || parts[0] != 'PQR') {
      return const _ScanResult(false, "Ce QR code n'est pas un QR de présence.");
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const _ScanResult(false, 'Tu dois être connecté.');
    }

    try {
      final db = FirebaseFirestore.instance;
      final sessionRef = db.collection('sessions').doc(parts[1]);
      final session = (await sessionRef.get()).data();
      if (session == null) {
        return const _ScanResult(false, 'Séance introuvable.');
      }
      if (session['code'] != parts[2]) {
        return const _ScanResult(false, 'QR code invalide.');
      }
      if (session['active'] != true) {
        return const _ScanResult(false, 'Cette séance est terminée.');
      }

      final matiere = session['matiere'] as String? ?? 'la séance';
      final attendance = sessionRef.collection('attendances').doc(user.uid);
      if ((await attendance.get()).exists) {
        return _ScanResult(
          true,
          'Ta présence est déjà enregistrée pour $matiere.',
        );
      }

      final profile = (await db.collection('users').doc(user.uid).get()).data();
      await attendance.set({
        'uid': user.uid,
        'email': user.email,
        'matricule': profile?['matricule'],
        'scannedAt': FieldValue.serverTimestamp(),
      });
      return _ScanResult(true, 'Présence enregistrée pour $matiere.');
    } on FirebaseException catch (e) {
      return _ScanResult(false, e.message ?? e.code);
    } catch (_) {
      return const _ScanResult(false, 'QR code illisible. Réessaie.');
    }
  }

  Future<void> _handle(String value) async {
    if (_busy) return;
    setState(() => _busy = true);

    final result = await _sign(value);
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          result.ok ? Icons.check_circle : Icons.error_outline,
          size: 48,
          color: result.ok ? Colors.green : Theme.of(ctx).colorScheme.error,
        ),
        content: Text(result.message, textAlign: TextAlign.center),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (!mounted) return;

    if (result.ok) {
      Navigator.pop(context);
    } else {
      setState(() => _busy = false); // on peut rescanner
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scanner un QR code')),
      body: Stack(
        children: [
          MobileScanner(
            onDetect: (capture) {
              for (final barcode in capture.barcodes) {
                final value = barcode.rawValue;
                if (value != null) {
                  _handle(value);
                  break;
                }
              }
            },
          ),
          Center(
            child: IgnorePointer(
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 3),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 48,
            child: Text(
              'Place le QR code dans le cadre',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
          if (_busy) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
