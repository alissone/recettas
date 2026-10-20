import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class RelayControllerException implements Exception {
  final String message;
  RelayControllerException(this.message);

  @override
  String toString() => message;
}

/// Talks to the ESP8266 eight-relay board over its small HTTP + JSON API,
/// reached through the home Tailscale subnet router:
///
///   GET /api/status          -> {"online": true, "relays": {"1": false, ...}}
///   PUT /api/relays/{n}      <- {"state": true}, -> same body as /status
///   GET /api/health          -> {"status": "ok", "uptime": 86400}
///
/// Commands are explicit ON/OFF (never toggles), so a retried request
/// can't flip a relay back.
class RelayController {
  RelayController._();

  static const relayCount = 8;
  static const defaultUrl = 'http://192.168.1.50';
  static const _urlKey = 'relay_controller_url';
  static const _tokenKey = 'relay_controller_token';
  static const _namesKey = 'relay_controller_names';
  static const _timeout = Duration(seconds: 5);

  static Future<String> getUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString(_urlKey) ?? defaultUrl;
    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  static Future<String> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey) ?? '';
  }

  static Future<void> saveSettings(
      {required String url, required String token}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_urlKey, url.trim());
    await prefs.setString(_tokenKey, token.trim());
  }

  /// User-given labels ("Bomba", "Luz da varanda"), index 0 = relay 1.
  static Future<List<String>> getNames() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_namesKey) ?? const [];
    return List.generate(relayCount,
        (i) => i < stored.length && stored[i].isNotEmpty
            ? stored[i]
            : 'Relé ${i + 1}');
  }

  static Future<void> setName(int relay, String name) async {
    final names = await getNames();
    names[relay - 1] = name.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_namesKey, names);
  }

  /// Current output state of every relay, index 0 = relay 1.
  static Future<List<bool>> getStatus() async {
    final res = await _send('GET', '/api/status');
    return _parseRelays(res);
  }

  /// Sets one relay and returns all states as reported after the
  /// firmware applied the output.
  static Future<List<bool>> setRelay(int relay, bool state) async {
    final res =
        await _send('PUT', '/api/relays/$relay', body: {'state': state});
    return _parseRelays(res);
  }

  /// Seconds since boot, or null when the controller doesn't answer.
  static Future<int?> getUptime() async {
    try {
      final res = await _send('GET', '/api/health');
      return (res['uptime'] as num?)?.toInt();
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>> _send(String method, String path,
      {Map<String, dynamic>? body}) async {
    final base = await getUrl();
    final token = await getToken();
    final headers = {
      'Content-Type': 'application/json',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
    final uri = Uri.parse('$base$path');

    final http.Response res;
    try {
      res = await (method == 'PUT'
              ? http.put(uri, headers: headers, body: jsonEncode(body))
              : http.get(uri, headers: headers))
          .timeout(_timeout);
    } catch (_) {
      throw RelayControllerException('Controlador indisponível em $base');
    }

    switch (res.statusCode) {
      case 200:
        return jsonDecode(res.body) as Map<String, dynamic>;
      case 401:
        throw RelayControllerException('Token inválido');
      case 400:
        throw RelayControllerException('Requisição inválida: ${res.body}');
      case 503:
        throw RelayControllerException(
            'Controlador não pode executar o comando agora');
      default:
        throw RelayControllerException('Erro HTTP ${res.statusCode}');
    }
  }

  /// Accepts both the plain form ({"3": true}) and the desired/actual
  /// form ({"3": {"desired": true, "actual": true}}), using "actual".
  static List<bool> _parseRelays(Map<String, dynamic> json) {
    final relays = json['relays'] as Map<String, dynamic>? ?? const {};
    return List.generate(relayCount, (i) {
      final v = relays['${i + 1}'];
      if (v is bool) return v;
      if (v is Map) return v['actual'] == true;
      return false;
    });
  }
}
