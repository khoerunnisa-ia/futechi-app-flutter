import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

/// Client for the POST /api/chat route (port of useChat +
/// DefaultChatTransport in techi-chat.tsx).
///
/// Credentials stay server-side: the app only ever talks to /api/chat and
/// never sees the gateway API key. `baseUrl` must point at the deployed
/// react-js host that serves the route.
class ChatClient extends ChangeNotifier {
  ChatClient({required this.baseUrl, http.Client? httpClient})
      : _client = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _client;
  final Uuid _uuid = const Uuid();

  List<ChatTurn> turns = [];
  ChatStatus status = ChatStatus.idle;
  String? error;

  StreamSubscription<String>? _subscription;
  final StringBuffer _assistantBuffer = StringBuffer();

  bool get busy => status == ChatStatus.submitted || status == ChatStatus.streaming;

  /// Sends the full conversation plus context; streams the assistant reply.
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

      final response = await _client.send(request);
      if (response.statusCode != 200) {
        final body = await response.stream.bytesToString();
        error = _extractError(body) ?? 'Techi AI sedang tidak tersedia.';
        status = ChatStatus.error;
        notifyListeners();
        return;
      }
      status = ChatStatus.streaming;
      _assistantBuffer
        ..clear()
        ..write('id:${_uuid.v4()}\n');
      turns = [...turns, ChatTurn(role: 'assistant', text: '')];
      notifyListeners();

      // UIMessage streams prepend a metadata line before the text delta.
      await for (final chunk in response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        if (chunk.isEmpty) continue;
        final parsed = _parseStreamLine(chunk);
        if (parsed != null) {
          _assistantBuffer.write(parsed);
          _updateLastTurn(_assistantBuffer.toString());
        }
      }
      status = ChatStatus.done;
    } catch (e) {
      error = 'Techi AI sedang tidak tersedia.';
      status = ChatStatus.error;
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

  void _updateLastTurn(String text) {
    if (turns.isEmpty) return;
    final last = turns.last;
    if (last.role != 'assistant') return;
    turns = [...turns.sublist(0, turns.length - 1), ChatTurn(
      id: last.id,
      role: last.role,
      text: text,
    )];
    notifyListeners();
  }

  /// UIMessage stream lines look like `0:"text"` for text parts and
  /// `{"type":"error",...}` for error frames. Returns text deltas only.
  String? _parseStreamLine(String line) {
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
        // Ignore unparseable frames.
      }
    }
    return null;
  }

  String? _extractError(String body) {
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
