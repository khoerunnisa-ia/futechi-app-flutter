import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../../config/env.dart';

/// Client untuk Techi AI Chat.
///
/// Mendukung dua mode berdasarkan konfigurasi `.env`:
///
/// **Mode A – Direct Cloud LLM (Tahap 3)**
/// Bila `LLM_API_KEY` terisi, request dikirim langsung ke endpoint
/// OpenAI-compatible (`LLM_BASE_URL`) menggunakan streaming SSE.
/// Tidak membutuhkan backend proxy; API key aman di `.env` lokal/device.
///
/// **Mode B – Backend Proxy (legacy)**
/// Bila `LLM_API_KEY` kosong, fallback ke `POST FUTECHI_CHAT_URL/api/chat`
/// (port of useChat + DefaultChatTransport di techi-chat.tsx).
/// Credentials tetap di server; app hanya berbicara ke `/api/chat`.
class ChatClient extends ChangeNotifier {
  ChatClient({http.Client? httpClient})
      : _overrideBaseUrl = null,
        _client = httpClient ?? http.Client();

  /// Buat [ChatClient] dengan baseUrl eksplisit (dipakai oleh tes).
  ChatClient.withBaseUrl({required String baseUrl, http.Client? httpClient})
      : _overrideBaseUrl = baseUrl,
        _client = httpClient ?? http.Client();

  final String? _overrideBaseUrl;
  final http.Client _client;

  List<ChatTurn> turns = [];
  ChatStatus status = ChatStatus.idle;
  String? error;

  StreamSubscription<String>? _subscription;
  final StringBuffer _assistantBuffer = StringBuffer();

  bool get busy =>
      status == ChatStatus.submitted || status == ChatStatus.streaming;

  // ── Mode detection ─────────────────────────────────────────────────────

  /// True bila mode direct cloud LLM aktif (LLM_API_KEY terisi).
  bool get _isDirectMode =>
      _overrideBaseUrl == null && (Env.llmApiKey?.isNotEmpty ?? false);

  // ── Public API ──────────────────────────────────────────────────────────

  /// Mengirim pesan + stream balasan asisten.
  Future<void> sendMessage({
    required String text,
    required String threadId,
    String? caseId,
  }) async {
    if (busy || text.trim().isEmpty) return;
    error = null;
    status = ChatStatus.submitted;
    turns = [...turns, ChatTurn(role: 'user', text: text.trim())];
    notifyListeners();

    try {
      if (_isDirectMode) {
        await _sendDirect(caseId: caseId);
      } else {
        await _sendProxy(threadId: threadId, caseId: caseId);
      }
      status = ChatStatus.done;
    } catch (e) {
      error = 'Techi AI sedang tidak tersedia.';
      status = ChatStatus.error;
      debugPrint('[Chat] Error: $e');
    } finally {
      _subscription?.cancel();
      notifyListeners();
    }
  }

  void stop() {
    _subscription?.cancel();
    if (status == ChatStatus.streaming || status == ChatStatus.submitted) {
      status = ChatStatus.done;
      notifyListeners();
    }
  }

  void reset(List<ChatTurn> initialTurns) {
    turns = initialTurns;
    status = ChatStatus.idle;
    error = null;
    notifyListeners();
  }

  // ── Mode A: Direct Cloud LLM (OpenAI-compatible SSE streaming) ──────────

  /// System prompt Futechi untuk Techi AI.
  static const _systemPrompt =
      'Kamu adalah Techi, asisten AI cerdas untuk peternak ayam di platform Futechi. '
      'Tugasmu membantu pemantauan kesehatan, jadwal feeding, analisis anomali sensor, '
      'dan memberikan rekomendasi perawatan ayam yang akurat dan mudah dipahami. '
      'Bila kamu mendiagnosa penyakit atau gangguan kesehatan, sertakan blok khusus '
      'dalam format berikut tepat SETELAH penjelasan utama:\n\n'
      '<SUSPECTION_RESULT>\n'
      '{\n'
      '  "disease": "Nama Penyakit",\n'
      '  "confidence": 85,\n'
      '  "rationale": "Alasan singkat diagnosis.",\n'
      '  "mitigation": ["Langkah 1", "Langkah 2"],\n'
      '  "medication": "Rekomendasi obat atau penanganan."\n'
      '}\n'
      '</SUSPECTION_RESULT>\n\n'
      'Bahasa: Bahasa Indonesia yang profesional namun ramah. '
      'Jangan pernah menampilkan API key atau informasi sensitif.';

  Future<void> _sendDirect({String? caseId}) async {
    final apiKey = Env.llmApiKey!;
    final model = Env.llmModel;
    final endpoint = Env.llmBaseUrl;

    // Bangun messages array OpenAI format
    final messages = <Map<String, dynamic>>[
      {'role': 'system', 'content': _systemPrompt},
      for (final turn in turns) {'role': turn.role, 'content': turn.text},
    ];

    // Tambahkan konteks case bila ada
    if (caseId != null) {
      final lastUserIdx = messages.lastIndexWhere((m) => m['role'] == 'user');
      if (lastUserIdx >= 0) {
        messages[lastUserIdx] = {
          'role': 'user',
          'content': '[Kasus: $caseId]\n${messages[lastUserIdx]['content']}',
        };
      }
    }

    final request = http.Request('POST', Uri.parse(endpoint))
      ..headers['Content-Type'] = 'application/json'
      ..headers['Authorization'] = 'Bearer $apiKey'
      ..headers['HTTP-Referer'] = 'https://futechi.app'
      ..headers['X-Title'] = 'Futechi Smart Farm'
      ..body = jsonEncode({
        'model': model,
        'messages': messages,
        'stream': true,
        'temperature': 0.7,
        'max_tokens': 1024,
      });

    debugPrint('[Chat] Direct LLM → $endpoint model=$model');

    final response = await _client.send(request);
    if (response.statusCode != 200) {
      final body = await response.stream.bytesToString();
      error = _extractOpenAIError(body) ?? 'Techi AI sedang tidak tersedia.';
      status = ChatStatus.error;
      notifyListeners();
      return;
    }

    _beginAssistantTurn();

    // Parse OpenAI SSE: "data: {...}\n\n" atau "data: [DONE]\n\n"
    final buffer = StringBuffer();
    await for (final chunk in response.stream.transform(utf8.decoder)) {
      buffer.write(chunk);
      // Proses baris-baris yang lengkap
      final raw = buffer.toString();
      final lines = raw.split('\n');
      // Simpan baris terakhir yang mungkin belum lengkap
      buffer
        ..clear()
        ..write(lines.last);

      for (final line in lines.sublist(0, lines.length - 1)) {
        if (line.startsWith('data: ')) {
          final data = line.substring(6).trim();
          if (data == '[DONE]') break;
          _processOpenAIChunk(data);
        }
      }
    }
    // Proses sisa buffer
    final remaining = buffer.toString().trim();
    if (remaining.startsWith('data: ') && remaining != 'data: [DONE]') {
      _processOpenAIChunk(remaining.substring(6).trim());
    }
  }

  void _processOpenAIChunk(String data) {
    try {
      final decoded = jsonDecode(data) as Map<String, dynamic>;
      final choices = decoded['choices'] as List<dynamic>?;
      if (choices == null || choices.isEmpty) return;
      final delta = (choices[0] as Map<String, dynamic>)['delta']
          as Map<String, dynamic>?;
      final content = delta?['content'] as String?;
      if (content != null && content.isNotEmpty) {
        _assistantBuffer.write(content);
        _updateLastTurn(_assistantBuffer.toString());
      }
    } on FormatException {
      // Ignore unparseable SSE chunks
    }
  }

  String? _extractOpenAIError(String body) {
    try {
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final err = decoded['error'] as Map<String, dynamic>?;
      return err?['message'] as String?;
    } on FormatException {
      return null;
    }
  }

  // ── Mode B: Backend Proxy (legacy react-js /api/chat route) ─────────────

  Future<void> _sendProxy({
    required String threadId,
    String? caseId,
  }) async {
    final baseUrl = _overrideBaseUrl ?? Env.chatBaseUrl;

    final request = http.Request(
      'POST',
      Uri.parse('$baseUrl/api/chat'),
    )
      ..headers['Content-Type'] = 'application/json'
      ..body = jsonEncode({
        'messages': [
          for (final turn in turns)
            {
              'id': turn.id,
              'role': turn.role,
              'parts': [
                {'type': 'text', 'text': turn.text},
              ],
            },
        ],
        'threadId': threadId,
        if (caseId != null) 'caseId': caseId,
      });

    debugPrint('[Chat] Proxy → $baseUrl/api/chat');

    final response = await _client.send(request);
    if (response.statusCode != 200) {
      final body = await response.stream.bytesToString();
      error = _extractProxyError(body) ?? 'Techi AI sedang tidak tersedia.';
      status = ChatStatus.error;
      notifyListeners();
      return;
    }

    _beginAssistantTurn();

    // UIMessage streams: "0:\"text\"" for text parts
    await for (final chunk in response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())) {
      if (chunk.isEmpty) continue;
      final parsed = _parseProxyStreamLine(chunk);
      if (parsed != null) {
        _assistantBuffer.write(parsed);
        _updateLastTurn(_assistantBuffer.toString());
      }
    }
  }

  String? _parseProxyStreamLine(String line) {
    if (line.length < 2) return null;
    final prefix = line[0];
    if (prefix == '0') {
      final quoted = line.substring(1);
      try {
        final decoded = jsonDecode(quoted);
        return decoded is String ? decoded : null;
      } on FormatException {
        return null;
      }
    }
    if (prefix == '{') {
      try {
        final decoded = jsonDecode(line);
        if (decoded is Map && decoded['type'] == 'error') {
          error = decoded['message'] as String? ?? error;
        }
      } on FormatException {
        // Ignore
      }
    }
    return null;
  }

  String? _extractProxyError(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['error'] is String) {
        return decoded['error'] as String;
      }
    } on FormatException {
      // Non-JSON error body.
    }
    return null;
  }

  // ── Shared helpers ───────────────────────────────────────────────────────

  void _beginAssistantTurn() {
    status = ChatStatus.streaming;
    _assistantBuffer.clear();
    turns = [...turns, ChatTurn(role: 'assistant', text: '')];
    notifyListeners();
  }

  void _updateLastTurn(String text) {
    if (turns.isEmpty) return;
    final last = turns.last;
    if (last.role != 'assistant') return;
    turns = [
      ...turns.sublist(0, turns.length - 1),
      ChatTurn(id: last.id, role: last.role, text: text),
    ];
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _client.close();
    super.dispose();
  }
}

enum ChatStatus { idle, submitted, streaming, done, error }

class ChatTurn {
  ChatTurn({String? id, required this.role, required this.text})
      : id = id ?? const Uuid().v4();

  final String id;
  final String role;
  final String text;
}
