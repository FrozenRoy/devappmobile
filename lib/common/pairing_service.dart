import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const _base = 'https://alto.samyn.ovh';
  static const _pairing = '$_base/pairing';

  static Future<Map<String, dynamic>?> postPairingInit(Map<String, dynamic> payload) async {
    try {
      final resp = await http.post(Uri.parse(_pairing), headers: {'Content-Type': 'application/json'}, body: json.encode(payload));
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        if (resp.body.isEmpty) return {};
        return json.decode(resp.body) as Map<String, dynamic>;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> putPairingMatch(Map<String, dynamic> payload) async {
    try {
      final resp = await http.put(Uri.parse(_pairing), headers: {'Content-Type': 'application/json'}, body: json.encode(payload));
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        if (resp.body.isEmpty) return {};
        return json.decode(resp.body) as Map<String, dynamic>;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getPairingStatus(String relationCode) async {
    try {
      final uri = Uri.parse('$_pairing/$relationCode/status');
      final resp = await http.get(uri, headers: {'Accept': 'application/json'});
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        if (resp.body.isEmpty) return {};
        return json.decode(resp.body) as Map<String, dynamic>;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> deletePairing(String relationCodeA) async {
    try {
      final uri = Uri.parse('$_pairing?relationCodeA=${Uri.encodeComponent(relationCodeA)}');
      final resp = await http.delete(uri, headers: {'Accept': 'application/json'});
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        if (resp.body.isEmpty) return {};
        return json.decode(resp.body) as Map<String, dynamic>;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}

