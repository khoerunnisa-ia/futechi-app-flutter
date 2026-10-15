import 'package:flutter_test/flutter_test.dart';
import 'package:futechi/screens/techi/suspicion_parser.dart';

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
}
