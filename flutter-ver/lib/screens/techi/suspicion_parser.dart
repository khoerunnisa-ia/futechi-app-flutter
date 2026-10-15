import 'dart:convert';

import '../../data/health_case.dart';

/// Port of the SUSPECTION_RESULT parsing logic from
/// react-js/src/components/techi-chat.tsx.

/// Extracts a SuspicionResult from an assistant message text, validating all
/// required fields. Returns null when the block is missing or malformed.
SuspicionResult? parseSuspicionResult(String messageText) {
  final pattern =
      RegExp(r'SUSPECTION_RESULT_START\s*([\s\S]*?)\s*SUSPECTION_RESULT_END');
  final match = pattern.firstMatch(messageText);
  final payload = match?.group(1);
  if (payload == null || payload.isEmpty) return null;
  try {
    final value = jsonDecode(payload);
    if (value is! Map<String, dynamic>) return null;
    final disease = value['disease'];
    final confidence = value['confidence'];
    final rationale = value['rationale'];
    final mitigation = value['mitigation'];
    final medication = value['medication'];
    if (disease is! String ||
        confidence is! num ||
        rationale is! String ||
        mitigation is! List ||
        medication is! String) {
      return null;
    }
    return SuspicionResult(
      disease: disease,
      confidence: confidence.toInt(),
      rationale: rationale,
      mitigation: mitigation.whereType<String>().toList(),
      medication: medication,
      submittedAt: DateTime.now().toUtc().toIso8601String(),
    );
  } on FormatException {
    return null;
  }
}

bool containsSuspicionBlock(String text) =>
    RegExp(r'SUSPECTION_RESULT_START').hasMatch(text);

bool isSuspicionSubmission(String text) => text.startsWith('[FORM SUSPECTION]');

/// Builds the [FORM SUSPECTION] prompt body sent to /api/chat, mirroring
/// `submitSuspicion` in techi-chat.tsx.
String buildSuspicionPrompt({
  required String chickenId,
  required List<({String disease, int baselineConfidence, List<({String symptom, bool observed})> symptoms})> observations,
}) {
  final encoded = jsonEncode([
    for (final o in observations)
      {
        'disease': o.disease,
        'baselineConfidence': o.baselineConfidence,
        'symptoms': [
          for (final s in o.symptoms) {'symptom': s.symptom, 'observed': s.observed},
        ],
      },
  ]);
  return '[FORM SUSPECTION]\n'
      'Peternak telah menyelesaikan pemeriksaan gejala untuk $chickenId. '
      'Analisis data berikut dan berikan hasil pemeriksaan terstruktur.\n'
      '$encoded';
}
