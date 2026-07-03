import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/receipt_job.dart';
import 'receipt_csv_parser.dart';
import 'supabase_service.dart';

class ServerUnavailableException implements Exception {
  final String url;
  ServerUnavailableException(this.url);

  @override
  String toString() => 'Servidor indisponível em $url';
}

/// Sends a queued receipt photo to the local llama-server (Qwen vision,
/// shared over Tailscale) and turns the returned CSV into purchases.
class ReceiptProcessor {
  ReceiptProcessor._();

  /// desktop-g67u1en on Tailscale, where qwen3.6-27b-q4-vision.bat runs.
  static const defaultServerUrl = 'http://100.68.235.8:8001';
  static const _prefsKey = 'llama_server_url';

  static const _model = 'qwen3.6-27b-vision';

  // Same prompt as cupom-scanner.html.
  static const _prompt =
      'Converta esse cupom em CSV, com as colunas: NOME, QUANTIDADE, '
      'VALOR UNITARIO, DATA, ESTABELECIMENTO.\n'
      'O estabelecimento fica em negrito ao topo depois do CNPJ. A data '
      'fica em negrito depois do numero de NFC-e e Serie no formato '
      'DD/MM/YYYY.\n'
      'IMPORTANTE: Use ponto (.) como separador decimal nos valores, NAO '
      'use virgula. Exemplo: 3.29 e nao 3,29.\n'
      'Retorne SOMENTE o CSV, sem explicacoes.';

  static Future<String> getServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString(_prefsKey) ?? defaultServerUrl;
    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  static Future<void> setServerUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, url.trim());
  }

  /// Quick reachability probe; the server is often powered off.
  static Future<bool> isServerAvailable([String? url]) async {
    final base = url ?? await getServerUrl();
    try {
      final res = await http
          .get(Uri.parse('$base/v1/models'))
          .timeout(const Duration(seconds: 4));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Processes one job end to end and returns how many purchases were
  /// created. Throws [ServerUnavailableException] when the server is off;
  /// any other failure marks the job as error (with the message) and
  /// rethrows.
  static Future<int> processJob(ReceiptJob job) async {
    final base = await getServerUrl();
    if (!await isServerAvailable(base)) {
      throw ServerUnavailableException(base);
    }

    await SupabaseService.updateReceiptJob(job.id,
        status: ReceiptJobStatus.processing);

    try {
      final imageBytes =
          await SupabaseService.downloadReceiptImage(job.imagePath);
      final dataUrl = 'data:image/jpeg;base64,${base64Encode(imageBytes)}';

      final res = await http
          .post(
            Uri.parse('$base/v1/chat/completions'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'model': _model,
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {
                      'type': 'image_url',
                      'image_url': {'url': dataUrl},
                    },
                    {'type': 'text', 'text': _prompt},
                  ],
                }
              ],
              'temperature': 0.6,
              'top_p': 0.95,
              'top_k': 20,
              'max_tokens': 4096,
            }),
          )
          .timeout(const Duration(minutes: 15));

      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode}: ${res.body}');
      }

      final content = jsonDecode(utf8.decode(res.bodyBytes))['choices'][0]
          ['message']['content'] as String;
      final items = ReceiptCsvParser.parse(content);
      if (items.isEmpty) {
        throw Exception('Nenhum item encontrado no cupom');
      }

      final uid = SupabaseService.currentUser!.id;
      final today = DateTime.now().toIso8601String().substring(0, 10);
      await SupabaseService.insertPurchases([
        for (final it in items)
          {
            'user_id': uid,
            'purchase_date': it.data.isNotEmpty ? it.data : today,
            'item': it.nome,
            'valor': it.valorTotal,
            'local': it.estabelecimento.isEmpty ? null : it.estabelecimento,
            'receipt_job_id': job.id,
          }
      ]);

      await SupabaseService.updateReceiptJob(job.id,
          status: ReceiptJobStatus.done, itemsCount: items.length);
      return items.length;
    } catch (e) {
      try {
        await SupabaseService.updateReceiptJob(job.id,
            status: ReceiptJobStatus.error, errorMessage: e.toString());
      } catch (_) {
        // Keep the original failure if even the status update fails.
      }
      rethrow;
    }
  }
}
