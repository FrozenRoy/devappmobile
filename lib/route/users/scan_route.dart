import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../common/pairing_service.dart';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:uuid/uuid.dart';

class ScannerRoute extends StatefulWidget {
  const ScannerRoute({super.key});

  @override
  State<ScannerRoute> createState() => _TestRouteState();
}

class _TestRouteState extends State<ScannerRoute> {
  bool _scanned = false;
  bool _isLoading = false;
  final MobileScannerController _controller = MobileScannerController();

  Future<void> _onBarcodeDetected(String value) async {
    if (_scanned) return;
    setState(() {
      _scanned = true;
      _isLoading = true;
    });

    await _controller.stop();

    try {
      String? url;
      String? relationCodeA;
      try {
        final decoded = json.decode(value);
        if (decoded is Map && decoded['relationCode'] != null) {
          relationCodeA = decoded['relationCode']?.toString();
        }
      } catch (_) {}

      final prefs = await SharedPreferences.getInstance();

      if (url != null) {
        await prefs.setString('my_url', url);
      } else {
        await prefs.setString('my_url', value);
      }

      if (relationCodeA != null && relationCodeA.isNotEmpty) {
        String? localPub = prefs.getString('local_pubkey');
        if (localPub == null || localPub.isEmpty) {
          final rnd = Random.secure();
          final bytes = List<int>.generate(32, (_) => rnd.nextInt(256));
          localPub = base64Encode(Uint8List.fromList(bytes));
          await prefs.setString('local_pubkey', localPub);
        }

        final relationCodeB = const Uuid().v4();

        final putResp = await ApiService.putPairingMatch({
          'relationCodeA': relationCodeA,
          'relationCodeB': relationCodeB,
          'publicKeyB': localPub,
        });

        if (putResp != null) {
          final publicKeyA = putResp['publicKeyA']?.toString() ?? putResp['userPublicKey']?.toString() ?? putResp['publicKey']?.toString();
          final relA = putResp['relationCodeA']?.toString() ?? relationCodeA;
          if (publicKeyA != null) {
            await prefs.setString('remote_pubkey', publicKeyA);
            await prefs.setString('relationCodeA', relA);
            await prefs.setString('relationCodeB', relationCodeB);
          }

          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Matching envoyé au serveur')));

          _startPollingForFinalize(relationCodeA);
          return;
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Échec du matching sur le serveur')));
          setState(() {
            _isLoading = false;
            _scanned = false;
          });
          await _controller.start();
          return;
        }
      }

    } catch (e) {
      setState(() {
        _isLoading = false;
        _scanned = false;
      });
      await _controller.start();
      return;
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _startPollingForFinalize(String relationCodeA) {
    const timeout = Duration(seconds: 30);
    const interval = Duration(seconds: 2);
    var elapsed = Duration.zero;

    Timer.periodic(interval, (timer) async {
      elapsed += interval;
      if (elapsed > timeout) {
        timer.cancel();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Timeout attente finalisation')));
        return;
      }

      final statusResp = await ApiService.getPairingStatus(relationCodeA);
      if (statusResp != null) {
        final status = statusResp['status']?.toString()?.toLowerCase();
        if (status == 'finalized') {
          timer.cancel();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pairing finalisé')));
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
        title: const Text('Scanner un QR code'),
        backgroundColor: const Color(0xFF202b3b),
        foregroundColor: const Color(0xFFf17122),
      ),
      body: Stack(
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: MobileScanner(
                  controller: _controller,
                  onDetect: (capture) {
                    final List<Barcode> barcodes = capture.barcodes;
                    for (final barcode in barcodes) {
                      final rawValue = barcode.rawValue;
                      if (rawValue != null) {
                        _onBarcodeDetected(rawValue);
                      }
                    }
                  },
                ),
              ),
            ],
          ),
          // Overlay de chargement
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Envoi en cours...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

