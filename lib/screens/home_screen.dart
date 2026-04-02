import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _hasRelation = false;

  @override
  void initState() {
    super.initState();
    _checkRelation();
  }

  Future<void> _checkRelation() async {
    final prefs = await SharedPreferences.getInstance();
    final relationCodeA = prefs.getString('relationCodeA');
    final relationCodeB = prefs.getString('relationCodeB');

    if (relationCodeA != null && relationCodeA.isNotEmpty && relationCodeB != null && relationCodeB.isNotEmpty) {
      setState(() {
        _hasRelation = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alto - Accueil'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              onPressed: () {
                // Naviguer vers l'écran de création/partage de connexion
                context.go('/connexion');
              },
              icon: const Icon(Icons.qr_code),
              label: const Text('Créer une connexion'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 18),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                // Naviguer vers l'écran de scan
                context.go('/scanner');
              },
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scanner un QR code'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 18),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Vos relations',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (!_hasRelation)
              const Expanded(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Text(
                      'Aucune relation pour le moment.\nCréez une connexion ou scannez une invitation pour commencer.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  ),
                ),
              )
            else ...[
              ElevatedButton.icon(
                onPressed: () {
                  context.go('/relation');
                },
                icon: const Icon(Icons.chat),
                label: const Text('Voir la discussion'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 18),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
