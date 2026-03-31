import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../common/api_service.dart';
import 'package:url_launcher/url_launcher.dart';

class ConnexionRoute extends StatefulWidget {
  const ConnexionRoute({super.key});

  @override
  State<ConnexionRoute> createState() => _ConnexionRouteState();
}

class _ConnexionRouteState extends State<ConnexionRoute> {
  String? _payloadJson;
  String? _displayUrl;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _preparePayload();
  }

  Future<void> _preparePayload() async {
    final prefs = await SharedPreferences.getInstance();

    final myUrl = prefs.getString('my_url') ?? 'https://alto.samyn.ovh/debug/pairing';

    // Générer ou récupérer la clé publique locale
    String? localPub = prefs.getString('local_pubkey');
    if (localPub == null || localPub.isEmpty) {
      final rnd = Random.secure();
      final bytes = List<int>.generate(32, (_) => rnd.nextInt(256));
      localPub = base64Encode(Uint8List.fromList(bytes));
      await prefs.setString('local_pubkey', localPub);
    }

    // Générer un relationCodeA (UUID)
    final relationCodeA = const Uuid().v4();

    // Poster l'init au serveur avec les champs attendus
    final resp = await ApiService.postPairingInit({'relationCode': relationCodeA, 'userPublicKey': localPub});

    // Le QR doit contenir uniquement relationCodeA
    setState(() {
      _payloadJson = json.encode({'relationCode': relationCodeA});
      _displayUrl = myUrl;
      _loading = false;
    });

    if (resp != null) {
      // Sauvegarder notre relationCodeA localement pour la suite
      final prefs2 = await SharedPreferences.getInstance();
      await prefs2.setString('relationCodeA', relationCodeA);

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pairing initialisé sur le serveur')));
      // Démarrer le polling pour attendre le match (status == 'completed')
      _startPollingForPeer(relationCodeA, localPub);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Échec envoi pairing (offline ?)')));
    }
  }

  void _startPollingForPeer(String relationCodeA, String localPub) {
    const timeout = Duration(seconds: 30);
    const interval = Duration(seconds: 2);
    var elapsed = Duration.zero;

    Timer.periodic(interval, (timer) async {
      elapsed += interval;
      if (elapsed > timeout) {
        timer.cancel();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aucun scanner détecté dans les 30s')));
        return;
      }
      final statusResp = await ApiService.getPairingStatus(relationCodeA);
      if (statusResp != null) {
        final status = (statusResp['status']?.toString() ?? '').toLowerCase();
        if (status == 'completed') {
          // Alice finalise : DELETE /pairing?relationCodeA=...
          final deleteResp = await ApiService.deletePairing(relationCodeA);
          if (deleteResp != null) {
            // On s'attend à recevoir { relationCodeB, publicKeyB }
            final pubB = deleteResp['publicKeyB']?.toString() ?? deleteResp['userPublicKey']?.toString() ?? deleteResp['publicKey']?.toString();
            final relationCodeB = deleteResp['relationCodeB']?.toString() ?? deleteResp['relationCode']?.toString();
            if (pubB != null && pubB.isNotEmpty) {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('remote_pubkey', pubB);
              if (relationCodeB != null) await prefs.setString('relationCodeB', relationCodeB);
            }
          }

          timer.cancel();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Clé distante reçue et sauvegardée')));
          if (mounted) context.go('/');
        }
      }
    });
  }

  // ...existing code...

  Future<void> _copyPayload() async {
    if (_payloadJson == null) return;
    await Clipboard.setData(ClipboardData(text: _payloadJson!));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payload copié dans le presse-papiers')));
  }

  Future<void> _openUrl() async {
    if (_displayUrl == null) return;
    final uri = Uri.tryParse(_displayUrl!);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Impossible d\'ouvrir l\'URL')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
          tooltip: 'Retour',
        ),
        title: const Text('Partager vos clés (QR)'),
        backgroundColor: const Color(0xFF202b3b),
        foregroundColor: const Color(0xFFf17122),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Center(
                    child: SizedBox(
                      width: 260,
                      height: 260,
                      child: QrImageView(
                        data: _payloadJson ?? '',
                        backgroundColor: Colors.white,
                        errorStateBuilder: (context, error) => const Center(child: Text('Impossible d\'afficher le QR code')),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SelectableText(
                    _payloadJson ?? '',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _copyPayload,
                        icon: const Icon(Icons.copy),
                        label: const Text('Copier'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _openUrl,
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('Ouvrir l\'URL'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}