import 'dart:convert';

import '../../data/health_case.dart';

/// Port of the SUSPECTION_RESULT parsing logic from
/// react-js/src/components/techi-chat.tsx.

const _startMarker = 'SUSPECTION_RESULT_START';
const _endMarker = 'SUSPECTION_RESULT_END';

/// Extracts a SuspicionResult from an assistant message text, validating all
/// required fields. Returns null when the block is missing or malformed.
///
/// Tolerates a missing END marker (stream stopped early) and markdown code
/// fences around the JSON object.
SuspicionResult? parseSuspicionResult(String messageText) {
  final start = messageText.indexOf(_startMarker);
  if (start < 0) return null;
  final bodyStart = start + _startMarker.length;
  final end = messageText.indexOf(_endMarker, bodyStart);
  final block = messageText.substring(bodyStart, end < 0 ? null : end);
  final open = block.indexOf('{');
  final close = block.lastIndexOf('}');
  if (open < 0 || close <= open) return null;
  final payload = block.substring(open, close + 1);
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

bool containsSuspicionBlock(String text) => text.contains(_startMarker);

/// Text outside the SUSPECTION_RESULT block (e.g. a short intro sentence).
String stripSuspicionBlock(String text) {
  final start = text.indexOf(_startMarker);
  if (start < 0) return text.trim();
  final end = text.indexOf(_endMarker, start);
  final after = end < 0 ? '' : text.substring(end + _endMarker.length);
  return '${text.substring(0, start)}$after'.trim();
}

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
