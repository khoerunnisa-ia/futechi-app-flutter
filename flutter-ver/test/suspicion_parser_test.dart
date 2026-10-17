import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:futechi/screens/techi/chat_client.dart';
import 'package:futechi/screens/techi/suspicion_parser.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _block = 'SUSPECTION_RESULT_START\n'
    '{"disease":"Newcastle Disease","confidence":88,"rationale":"Gejala cocok.",'
    '"mitigation":["Isolasi","Desinfeksi","Hubungi dokter hewan"],'
    '"medication":"Antiviral suportif atas persetujuan dokter hewan"}\n'
    'SUSPECTION_RESULT_END';

/// Splits [text] into UI message stream SSE lines (AI SDK `toUIMessageStreamResponse`).
List<String> _sseLines(String text, {int chunk = 20}) => [
      'data: {"type":"start"}',
      'data: {"type":"text-start","id":"t1"}',
      for (var i = 0; i < text.length; i += chunk)
        'data: ${jsonEncode({
              'type': 'text-delta',
              'id': 't1',
              'delta': text.substring(i, i + chunk > text.length ? text.length : i + chunk),
            })}',
      'data: {"type":"text-end","id":"t1"}',
      'data: {"type":"finish"}',
      'data: [DONE]',
    ];

MockClient _sseClient(List<String> lines, {void Function(Map<String, dynamic>)? onBody}) =>
    MockClient.streaming((request, bodyStream) async {
      final body = await bodyStream.bytesToString();
      onBody?.call(jsonDecode(body) as Map<String, dynamic>);
      return http.StreamedResponse(
        Stream.fromIterable([for (final l in lines) utf8.encode('$l\n\n')]),
        200,
      );
    });

String _suspicionPrompt() => buildSuspicionPrompt(
      chickenId: 'AYM-A3-23',
      observations: [
        (
          disease: 'Newcastle Disease',
          baselineConfidence: 94,
          symptoms: [(symptom: 'Leher terpuntir', observed: true)],
        ),
      ],
    );

void main() {
  test('parses a valid suspection block', () {
    const message = 'Analisis selesai.\n'
        'SUSPECTION_RESULT_START\n'
        '{"disease":"Newcastle Disease","confidence":94,'
        '"rationale":"Gejala cocok.","mitigation":["Isolasi","Periksa suhu","Hubungi dokter"],'
        '"medication":"Konsultasi dokter hewan"}\n'
        'SUSPECTION_RESULT_END';
    final result = parseSuspicionResult(message);
    expect(result, isNotNull);
    expect(result!.disease, 'Newcastle Disease');
    expect(result.confidence, 94);
    expect(result.mitigation, hasLength(3));
    expect(result.medication, 'Konsultasi dokter hewan');
  });

  test('returns null for missing fields', () {
    const message = 'SUSPECTION_RESULT_START {"disease":"X"} SUSPECTION_RESULT_END';
    expect(parseSuspicionResult(message), isNull);
  });

  test('returns null for malformed JSON', () {
    const message = 'SUSPECTION_RESULT_START {not json} SUSPECTION_RESULT_END';
    expect(parseSuspicionResult(message), isNull);
  });

  test('returns null when block is absent', () {
    expect(parseSuspicionResult('Pesan biasa tanpa blok.'), isNull);
  });

  test('filters non-string mitigation entries', () {
    const message = 'SUSPECTION_RESULT_START '
        '{"disease":"A","confidence":50,"rationale":"r",'
        '"mitigation":["ok",42],"medication":"m"} '
        'SUSPECTION_RESULT_END';
    final result = parseSuspicionResult(message);
    expect(result!.mitigation, ['ok']);
  });

  test('buildSuspicionPrompt wraps observations', () {
    final prompt = buildSuspicionPrompt(
      chickenId: 'AYM-A3-23',
      observations: [
        (
          disease: 'Heat Stress',
          baselineConfidence: 86,
          symptoms: [(symptom: 'Napas cepat', observed: true)],
        ),
      ],
    );
    expect(prompt.startsWith('[FORM SUSPECTION]'), isTrue);
    expect(prompt.contains('AYM-A3-23'), isTrue);
    expect(prompt.contains('"observed":true'), isTrue);
  });

  test('parses a block wrapped in a markdown code fence', () {
    const message = 'SUSPECTION_RESULT_START\n```json\n'
        '{"disease":"Coryza","confidence":70,"rationale":"r",'
        '"mitigation":["a","b","c"],"medication":"m"}\n```\n'
        'SUSPECTION_RESULT_END';
    expect(parseSuspicionResult(message)?.disease, 'Coryza');
  });

  test('parses a complete JSON object when the END marker is missing (stopped)', () {
    final message = _block.replaceAll('SUSPECTION_RESULT_END', '');
    expect(parseSuspicionResult(message)?.disease, 'Newcastle Disease');
  });

  test('returns null for a truncated JSON object', () {
    expect(parseSuspicionResult(_block.substring(0, 60)), isNull);
  });

  test('stripSuspicionBlock keeps only the text outside the block', () {
    expect(stripSuspicionBlock('Analisis selesai.\n$_block\nSalam.'),
        'Analisis selesai.\n\nSalam.');
    expect(stripSuspicionBlock(_block), isEmpty);
    expect(stripSuspicionBlock('Pesan biasa'), 'Pesan biasa');
  });

  group('ChatClient proxy mode', () {
    test('streams UI message SSE text-delta and yields a parseable result', () async {
      final client = ChatClient.withBaseUrl(
        baseUrl: 'http://proxy.test',
        httpClient: _sseClient(_sseLines(_block)),
      );
      await client.sendMessage(
          text: _suspicionPrompt(), threadId: 'alert-a24', caseId: 'a24');

      expect(client.status, ChatStatus.done);
      expect(client.error, isNull);
      expect(client.turns.last.role, 'assistant');
      final result = parseSuspicionResult(client.turns.last.text);
      expect(result, isNotNull);
      expect(result!.disease, 'Newcastle Disease');
      expect(result.mitigation, hasLength(3));
    });

    test('attaches the format instruction to [FORM SUSPECTION] without a system message',
        () async {
      late Map<String, dynamic> body;
      final client = ChatClient.withBaseUrl(
        baseUrl: 'http://proxy.test',
        httpClient: _sseClient(_sseLines('ok'), onBody: (b) => body = b),
      );
      await client.sendMessage(
          text: _suspicionPrompt(), threadId: 'alert-a24', caseId: 'a24');

      final messages = (body['messages'] as List).cast<Map<String, dynamic>>();
      expect(messages.where((m) => m['role'] == 'system'), isEmpty);
      final text = (messages.last['parts'] as List).first['text'] as String;
      expect(text.startsWith('[FORM SUSPECTION]'), isTrue);
      expect(text, contains('SUSPECTION_RESULT_START'));
      expect(text, contains('SUSPECTION_RESULT_END'));
      expect(body['caseId'], 'a24');
      // The stored turn stays as typed (the instruction is payload-only).
      expect(client.turns.first.text, _suspicionPrompt());
    });

    test('normal messages are sent unchanged', () {
      final turn = ChatTurn(role: 'user', text: 'Halo Techi');
      expect(ChatClient.proxyTurnText(turn), 'Halo Techi');
    });

    test('still supports the legacy 0:"text" data stream', () async {
      final client = ChatClient.withBaseUrl(
        baseUrl: 'http://proxy.test',
        httpClient: _sseClient(['0:${jsonEncode('Halo ')}', '0:${jsonEncode('Anne')}']),
      );
      await client.sendMessage(text: 'Hai', threadId: 't1');
      expect(client.turns.last.text, 'Halo Anne');
    });

    test('reports SSE error events', () async {
      final client = ChatClient.withBaseUrl(
        baseUrl: 'http://proxy.test',
        httpClient: _sseClient(['data: {"type":"error","errorText":"Kuota habis"}']),
      );
      await client.sendMessage(text: 'Hai', threadId: 't1');
      expect(client.error, 'Kuota habis');
    });

    test('stop() ends the stream as done and keeps the partial result parseable',
        () async {
      final controller = StreamController<List<int>>();
      final client = ChatClient.withBaseUrl(
        baseUrl: 'http://proxy.test',
        httpClient: MockClient.streaming((request, bodyStream) async {
          await bodyStream.drain<void>();
          return http.StreamedResponse(controller.stream, 200);
        }),
      );
      final sending = client.sendMessage(text: _suspicionPrompt(), threadId: 't1');
      final partial = _block.replaceAll('SUSPECTION_RESULT_END', '');
      for (final line in _sseLines(partial).take(_sseLines(partial).length - 3)) {
        controller.add(utf8.encode('$line\n\n'));
      }
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(client.status, ChatStatus.streaming);

      client.stop();
      expect(client.status, ChatStatus.done);
      controller.add(utf8.encode('data: {"type":"text-delta","id":"t1","delta":"x"}\n\n'));
      await controller.close();
      await sending;

      expect(client.status, ChatStatus.done);
      expect(parseSuspicionResult(client.turns.last.text)?.disease,
          'Newcastle Disease');
    });

    test('keeps the error status for non-200 responses', () async {
      final client = ChatClient.withBaseUrl(
        baseUrl: 'http://proxy.test',
        httpClient: MockClient((_) async =>
            http.Response(jsonEncode({'error': 'Techi AI belum dikonfigurasi.'}), 401)),
      );
      await client.sendMessage(text: 'Hai', threadId: 't1');
      expect(client.status, ChatStatus.error);
      expect(client.error, 'Techi AI belum dikonfigurasi.');
    });
  });
}
