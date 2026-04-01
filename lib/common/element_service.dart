import 'dart:convert';
import 'package:http/http.dart' as http;

class ElementService {
  static const _base = 'https://alto.samyn.ovh/';
  static const _elementEndpoint = '${_base}element';

  /// POST /element
  static Future<Map<String, dynamic>?> postElement(
      Map<String, dynamic> payload) async {
    try {
      final resp = await http.post(
        Uri.parse(_elementEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      );
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        if (resp.body.isEmpty) return <String, dynamic>{};
        return json.decode(resp.body) as Map<String, dynamic>;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// DELETE /element
  static Future<bool> deleteElement(Map<String, dynamic> payload) async {
    try {
      final request = http.Request('DELETE', Uri.parse(_elementEndpoint));
      request.headers['Content-Type'] = 'application/json';
      request.body = json.encode(payload);

      final resp = await http.Client().send(request);
      return resp.statusCode >= 200 && resp.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  /// GET /element (global)
  static Future<Map<String, dynamic>?> getAllElements() async {
    try {
      final resp = await http.get(
        Uri.parse(_elementEndpoint),
        headers: {'Accept': 'application/json'},
      );
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        if (resp.body.isEmpty) return <String, dynamic>{};
        return json.decode(resp.body) as Map<String, dynamic>;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// GET du get golbal et filtrage local pour une relation donnée
  static Future<List<Map<String, dynamic>>> getElementsForRelation(
      String relationCode) async {
    final all = await getAllElements();
    if (all == null) return [];

    final data = all['data'];
    if (data == null || data is! Map<String, dynamic>) return [];

    final listRaw = data[relationCode];
    if (listRaw == null || listRaw is! List) return [];

    final parsed = <Map<String, dynamic>>[];
    for (final item in listRaw) {
      if (item is Map<String, dynamic>) {
        final creationDateStr = item['creationDate']?.toString();
        DateTime? creationDate;
        if (creationDateStr != null) {
          try {
            creationDate = DateTime.parse(creationDateStr);
          } catch (_) {
            creationDate = null;
          }
        }
        final key = item['key']?.toString() ?? '';
        final rawValue = item['value']?.toString() ?? '';

        dynamic parsedValue;
        try {
          parsedValue = json.decode(rawValue);
        } catch (_) {
          parsedValue = null;
        }

        parsed.add({
          'creationDate': creationDate,
          'key': key,
          'rawValue': rawValue,
          'parsedValue': parsedValue,
        });
      }
    }

    parsed.sort((a, b) {
      final da = a['creationDate'] as DateTime?;
      final db = b['creationDate'] as DateTime?;
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return da.compareTo(db);
    });

    return parsed;
  }

  /// GET des éléments d'une relation et transformation en messages de chat
  static Future<List<Map<String, dynamic>>> getMessagesForRelation(
      String relationCode) async {
    final elems = await getElementsForRelation(relationCode);
    final messages = <Map<String, dynamic>>[];
    for (final e in elems) {
      final creationDate = e['creationDate'] as DateTime?;
      final parsed = e['parsedValue'];
      if (parsed is Map<String, dynamic>) {
        final messageId = parsed['messageId']?.toString();
        final senderId = parsed['senderId']?.toString();
        final content = parsed['content'] ?? parsed['value'] ?? parsed['text'] ?? parsed['body'];
        String? type = parsed['type']?.toString();
        DateTime? sentAt;
        if (parsed['sentAt'] != null) {
          try {
            sentAt = DateTime.parse(parsed['sentAt'].toString());
          } catch (_) {
            sentAt = creationDate;
          }
        } else {
          sentAt = creationDate;
        }

        messages.add({
          'messageId': messageId,
          'senderId': senderId,
          'content': content?.toString() ?? '',
          'type': type ?? 'texte',
          'sentAt': sentAt,
        });
      } else {
        messages.add({
          'messageId': null,
          'senderId': null,
          'content': e['rawValue']?.toString() ?? '',
          'type': 'texte',
          'sentAt': creationDate,
        });
      }
    }

    messages.sort((a, b) {
      final da = a['sentAt'] as DateTime?;
      final db = b['sentAt'] as DateTime?;
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return da.compareTo(db);
    });

    return messages;
  }
}