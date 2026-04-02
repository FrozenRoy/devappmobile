import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../common/pairing_service.dart';

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

    String? localPub = prefs.getString('local_pubkey');
    if (localPub == null || localPub.isEmpty) {
      final rnd = Random.secure();
      final bytes = List<int>.generate(32, (_) => rnd.nextInt(256));
      localPub = base64Encode(Uint8List.fromList(bytes));
      await prefs.setString('local_pubkey', localPub);
    }

    final relationCodeA = const Uuid().v4();

    final resp = await ApiService.postPairingInit({'relationCode': relationCodeA, 'userPublicKey': localPub});

    setState(() {
      _payloadJson = json.encode({'relationCode': relationCodeA});
      _displayUrl = myUrl;
      _loading = false;
    });

    if (resp != null) {
      final prefs2 = await SharedPreferences.getInstance();
      await prefs2.setString('relationCodeA', relationCodeA);

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pairing initialisé sur le serveur')));
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
          final deleteResp = await ApiService.deletePairing(relationCodeA);
          if (deleteResp != null) {
            final pubB = deleteResp['publicKeyB']?.toString() ?? deleteResp['userPublicKey']?.toString() ?? deleteResp['publicKey']?.toString();
            final relationCodeB = deleteResp['relationCodeB']?.toString() ?? deleteResp['relationCode']?.toString();
            if (pubB != null && pubB.isNotEmpty) {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('remote_pubkey', pubB);
              if (relationCodeB != null) await prefs.setString('relationCodeB', relationCodeB);
              await prefs.setBool('isDeviceA', true);
            }
          }

          timer.cancel();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Clé distante reçue et sauvegardée')));
          if (mounted) context.go('/');
        }
      }
    });
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
                ],
              ),
            ),
    );
  }
}