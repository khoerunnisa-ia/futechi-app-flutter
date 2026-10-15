import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Port of react-js/src/hooks/use-techi-threads.ts
///
/// Thread history stays device-specific: stored in shared_preferences
/// (browser-localStorage equivalent), never synced to an account.
library;

class StoredThread {
  StoredThread({
    required this.id,
    required this.title,
    required this.updatedAt,
    required this.messages,
    required this.checklist,
    this.selectedSymptoms = const [],
    this.caseStatus = 'pending',
  });

  final String id;
  final String title;
  final String updatedAt;
  final List<ChatMessage> messages;
  final List<String> checklist;
  final List<String> selectedSymptoms;
  /// 'pending' | 'sick' | 'healthy'
  final String caseStatus;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'updatedAt': updatedAt,
        'messages': [for (final m in messages) m.toJson()],
        'checklist': checklist,
        'selectedSymptoms': selectedSymptoms,
        'caseStatus': caseStatus,
      };

  static StoredThread fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final updatedAt = json['updatedAt'];
    if (id is! String || updatedAt is! String) {
      throw const FormatException('invalid thread');
    }
    final messages = (json['messages'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(ChatMessage.fromJson)
        .toList();
    return StoredThread(
      id: id,
      title: json['title'] as String? ?? 'Konsultasi operasional',
      updatedAt: updatedAt,
      messages: messages,
      checklist: (json['checklist'] as List<dynamic>? ?? [])
          .whereType<String>()
          .toList(),
      selectedSymptoms: (json['selectedSymptoms'] as List<dynamic>? ?? [])
          .whereType<String>()
          .toList(),
      caseStatus: json['caseStatus'] as String? ?? 'pending',
    );
  }
}

/// Minimal chat message model matching the parts of the UI we render.
class ChatMessage {
  ChatMessage({required this.id, required this.role, required this.text});

  final String id;
  /// 'user' | 'assistant'
  final String role;
  final String text;

  Map<String, dynamic> toJson() => {'id': id, 'role': role, 'text': text};

  static ChatMessage fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as String? ?? const Uuid().v4(),
        role: json['role'] as String? ?? 'assistant',
        text: json['text'] as String? ?? '',
      );
}

class TechiThreads extends ChangeNotifier {
  TechiThreads._();
  static final TechiThreads instance = TechiThreads._();

  static const _storageKey = 'futechi-techi-threads-v1';

  final List<StoredThread> _threads = [];
  bool _loaded = false;
  bool get loaded => _loaded;

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    _threads
      ..clear()
      ..addAll(_decode(raw));
    _loaded = true;
    notifyListeners();
  }

  List<StoredThread> get threads => List.unmodifiable(_threads);

  StoredThread? thread(String id) {
    for (final t in _threads) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// Inserts or updates a thread and keeps the list sorted by updatedAt desc.
  void upsert(StoredThread threadData) {
    _threads.removeWhere((t) => t.id == threadData.id);
    _threads.add(threadData);
    _threads.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    _persist();
    notifyListeners();
  }

  /// Creates (or returns existing) thread state for a fresh visit.
  StoredThread ensureThread(String threadId, String title, ChatMessage welcome) {
    final existing = thread(threadId);
    if (existing != null) return existing;
    final created = StoredThread(
      id: threadId,
      title: title,
      updatedAt: DateTime.now().toUtc().toIso8601String(),
      messages: [welcome],
    );
    upsert(created);
    return created;
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode([for (final t in _threads) t.toJson()]),
    );
  }

  static List<StoredThread> _decode(String? raw) {
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>? ?? [];
      final result = <StoredThread>[];
      for (final item in decoded) {
        if (item is! Map<String, dynamic>) continue;
        try {
          result.add(StoredThread.fromJson(item));
        } on FormatException {
          // Drop invalid entries rather than crashing the chat.
        }
      }
      return result;
    } on FormatException {
      return [];
    }
  }
}
