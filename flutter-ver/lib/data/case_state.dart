/// Port of react-js/src/lib/futechi-case-state.ts
///
/// Shared per-device case state (status + suspicion result per case id) kept in
/// sync across History, case details, and Techi via a ChangeNotifier +
/// shared_preferences (replacement for the browser localStorage store).
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'health_case.dart';

class CaseEntry {
  const CaseEntry({this.status, this.suspicionResult});
  final CaseStatus? status;
  final SuspicionResult? suspicionResult;
}

class CaseStateStore extends ChangeNotifier {
  CaseStateStore._();
  static final CaseStateStore instance = CaseStateStore._();

  static const _storageKey = 'futechi-case-state-v3';

  Map<String, CaseEntry> _cases = {};
  bool _loaded = false;
  bool get loaded => _loaded;

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    _cases = _decode(prefs.getString(_storageKey));
    _loaded = true;
    notifyListeners();
  }

  CaseStatus statusFor(HealthCase healthCase) =>
      _cases[healthCase.id]?.status ?? healthCase.initialStatus;

  SuspicionResult? suspicionFor(String caseId) =>
      _cases[caseId]?.suspicionResult;

  Future<void> setStatus(String caseId, CaseStatus status) =>
      _update(caseId, CaseEntry(status: status));

  Future<void> setSuspicionResult(String caseId, SuspicionResult result) =>
      _update(caseId, CaseEntry(suspicionResult: result));

  Future<void> _update(String caseId, CaseEntry patch) async {
    final current = _cases[caseId] ?? const CaseEntry();
    _cases = {
      ..._cases,
      caseId: CaseEntry(
        status: patch.status ?? current.status,
        suspicionResult: patch.suspicionResult ?? current.suspicionResult,
      ),
    };
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(_mapToJson()));
    notifyListeners();
  }

  Map<String, dynamic> _mapToJson() => _cases.map((caseId, entry) {
        final status = entry.status;
        final suspicion = entry.suspicionResult;
        return MapEntry(caseId, {
          if (status != null) 'status': status.name,
          if (suspicion != null) 'suspicionResult': suspicion.toJson(),
        });
      });

  static Map<String, CaseEntry> _decode(String? raw) {
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>? ?? {};
      return decoded.map((caseId, value) {
        final map = value as Map<String, dynamic>? ?? {};
        final statusName = map['status'] as String?;
        return MapEntry(
          caseId,
          CaseEntry(
            status: statusName == null
                ? null
                : CaseStatus.values.firstWhere(
                    (s) => s.name == statusName,
                    orElse: () => CaseStatus.pending,
                  ),
            suspicionResult: map['suspicionResult'] != null
                ? SuspicionResult.fromJson(
                    map['suspicionResult'] as Map<String, dynamic>)
                : null,
          ),
        );
      });
    } catch (_) {
      return {};
    }
  }
}
