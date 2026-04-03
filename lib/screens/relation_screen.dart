import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import '../common/element_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class RelationScreen extends StatefulWidget {
  const RelationScreen({super.key});

  @override
  State<RelationScreen> createState() => _RelationScreenState();
}

class _RelationScreenState extends State<RelationScreen> {
  late TextEditingController _messageController = TextEditingController();
  List<Map<String, dynamic>> messages = [];

  Future<void> _sendMessage() async {
    final prefs = await SharedPreferences.getInstance();
    final relationCodeA = prefs.getString('relationCodeA');
    final relationCodeB = prefs.getString('relationCodeB');
    final isDeviceA = prefs.getBool('isDeviceA') ?? true;

    final targetCode = isDeviceA ? relationCodeB : relationCodeA;

    if (targetCode != null) {
      final textMessage = _messageController.text.trim();
      if (textMessage.isEmpty) return;

      final creationDate = DateTime.now().toUtc().toIso8601String();
      final payload = {
        'relationCode': targetCode,
        'creationDate': creationDate,
        'key': 'MESSAGE',
        'value': textMessage,
      };

      _messageController.clear();

      if (mounted) {
        setState(() {
          messages.add({
            'content': textMessage,
            'sentAt': creationDate,
            'isMe': true,
          });
        });
      }

      await ElementService.postElement(payload);
      await _LoadMessages();
    }
  }

  Future<void> _LoadMessages() async {
      final prefs = await SharedPreferences.getInstance();
      final relationCodeA = prefs.getString('relationCodeA');
      final relationCodeB = prefs.getString('relationCodeB');
      final isDeviceA = prefs.getBool('isDeviceA') ?? true;

      final myCode = isDeviceA ? relationCodeA : relationCodeB;

      if (myCode != null) {
          final newMessages = await ElementService.getMessagesForRelation(myCode);
          if (mounted && newMessages.isNotEmpty) {
            final mappedMessages = newMessages.map((m) {
              final newMap = Map<String, dynamic>.from(m);
              newMap['isMe'] = false;
              return newMap;
            }).toList();
            setState(() {
              messages.addAll(mappedMessages);
            });
          }
    }
  }

  Color _bulleColor(String colorString) {
    final color = colorString.toLowerCase().trim();

    final colorMap = {
      'rouge': Colors.red[100]!,
      'vert': Colors.green[100]!,
      'bleu': Colors.blue[100]!,
      'jaune': Colors.yellow[100]!,
      'orange': Colors.orange[100]!,
      'rose': Colors.pink[100]!,
      'violet': Colors.purple[100]!,
    };

    return colorMap[color] ?? Colors.blue[100]!;
  }

  @override
  void initState() {
    super.initState();
    const time = Duration( seconds: 2);
    Timer.periodic(time, (Timer t) => _LoadMessages());
    _messageController = TextEditingController();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alto - Relation'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
          tooltip: 'Retour',
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final msg = messages[index];
                final isMe = msg['isMe'] == true;
                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 16.0),
                    padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
                    decoration: BoxDecoration(
                      color: isMe ? _bulleColor(msg['content']?.toString() ?? '') : Colors.grey[300],
                      borderRadius: BorderRadius.circular(16.0),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          msg['content']?.toString() ?? '',
                          style: TextStyle(
                            color: isMe ? Colors.black87 : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 16.0, 60.0, 50.0),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Message',
                ),
              ),
            ),
            IconButton(
              icon: const Icon(CupertinoIcons.paperplane_fill, size: 36),
              onPressed: () {
                _sendMessage();
              },
            ),
          ],
        ),
      ),
    );
  }
}
