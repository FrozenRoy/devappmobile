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

  /// GET web service pour récupérer les messages liés à une relation
  static Future<List<Map<String, dynamic>>> getMessagesForRelation(
      String relationCode) async {
    try {
      final resp = await http.get(
        Uri.parse('$_elementEndpoint?relationCode=$relationCode'),
        headers: {'Accept': 'application/json'},
      );
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        if (resp.body.isEmpty) return [];
        final data = json.decode(resp.body) as Map<String, dynamic>;
        final listRaw = data['elements'] ?? data[relationCode] ?? data['data']?[relationCode];

        if (listRaw is List) {
          return listRaw.whereType<Map<String, dynamic>>().map((item) => {
            'content': item['value']?.toString() ?? '',
            'sentAt': item['creationDate']?.toString(),
          }).toList();
        }
      }
      return [];
    } catch (_) {
      return [];
    }
  }
}