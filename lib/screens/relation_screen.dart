import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
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
    final relationCodeB = prefs.getString('relationCodeB');

    if (relationCodeB != null) {
      final textMessage = _messageController.text.trim();
      if (textMessage.isEmpty) return;

      final creationDate = DateTime.now().toUtc().toIso8601String();
      final payload = {
        'relationCode': relationCodeB,
        'creationDate': creationDate,
        'key': 'MESSAGE',
        'value': textMessage,
      };

      _messageController.clear();

      if (mounted) {
        setState(() {
          messages.insert(0, {
            'content': textMessage,
            'sentAt': creationDate,
          });
        });
      }

      await ElementService.postElement(payload);
      await _LoadMessages();
    }
  }

  Future<void> _LoadMessages() async {
      final prefs = await SharedPreferences.getInstance();
      final relationCodeB = prefs.getString('relationCodeB');

      if (relationCodeB != null) {
          final newMessages = await ElementService.getMessagesForRelation(relationCodeB);
          if (mounted) {
            setState(() {
              messages = newMessages.reversed.toList();
            });
          }
    }
  }

  @override
  void initState() {
    super.initState();
    const time = Duration( seconds: 5);
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
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final msg = messages[index];
                return Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 16.0),
                    padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          msg['content']?.toString() ?? '',
                        ),
                        const SizedBox(height: 4),
                        Text(
                          msg['sentAt']?.toString() ?? '',
                        ),
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
