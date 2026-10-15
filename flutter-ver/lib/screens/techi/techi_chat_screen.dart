import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../data/case_state.dart';
import '../../data/health_case.dart';
import 'chat_client.dart';
import 'suspicion_parser.dart';
import 'techi_threads.dart';

/// Port of react-js/src/components/techi-chat.tsx.
///
/// Chat UI with per-device thread persistence (shared_preferences), case
/// status card, Form Suspection, and SUSPECTION_RESULT rendering. History is
/// not synced to any account, matching the device-local storage decision.
class TechiChatScreen extends StatefulWidget {
  const TechiChatScreen({super.key, required this.threadId});

  final String threadId;

  @override
  State<TechiChatScreen> createState() => _TechiChatScreenState();
}

class _TechiChatScreenState extends State<TechiChatScreen> {
  late final HealthCase? healthCase;
  late ChatClient _client;
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _sidebarVisible = true;
  List<String> _checked = [];
  List<String> _selectedSymptoms = [];
  bool _restored = false;

  TechiThreads get _threads => TechiThreads.instance;
  CaseStateStore get _caseStore => CaseStateStore.instance;

  @override
  void initState() {
    super.initState();
    healthCase = getCaseFromThreadId(widget.threadId);
    _client = ChatClient(baseUrl: _chatBaseUrl());
    _client.addListener(_onChatChanged);
    _threads.load();
    _caseStore.load();
    _caseStore.addListener(_onStoresChanged);
  }

  @override
  void dispose() {
    _client.removeListener(_onChatChanged);
    _caseStore.removeListener(_onStoresChanged);
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _chatBaseUrl() {
    // Points at the react-js deployment serving POST /api/chat.
    return const String.fromEnvironment(
      'FUTECHI_CHAT_URL',
      defaultValue: 'http://localhost:3000',
    );
  }

  void _onChatChanged() {
    final turns = _client.turns;
    if (turns.isNotEmpty && _client.status == ChatStatus.done) {
      _persist(turns);
      if (healthCase != null) {
        final last = turns.last;
        if (last.role == 'assistant') {
          final result = parseSuspicionResult(last.text);
          if (result != null) {
            _caseStore.setSuspicionResult(healthCase!.id, result);
          }
        }
      }
    }
    if (mounted) setState(() {});
    _scrollToBottom();
  }

  void _onStoresChanged() {
    if (mounted) setState(() {});
  }

  void _restoreFromThread() {
    final stored = _threads.thread(widget.threadId);
    if (stored != null && !_restored) {
      _restored = true;
      final turns = [
        for (final message in stored.messages)
          ChatTurn(id: message.id, role: message.role, text: message.text),
      ];
      _client.reset(turns.isEmpty ? [_welcomeTurn()] : turns);
      _checked = stored.checklist;
      _selectedSymptoms = stored.selectedSymptoms;
      if (healthCase != null && stored.caseStatus != 'pending') {
        // Keep shared case state as the source of truth for status.
      }
    } else if (stored == null) {
      _threads.ensureThread(widget.threadId, _threadTitle(), _welcomeMessage());
      _client.reset([_welcomeTurn()]);
      _restored = true;
    }
  }

  ChatTurn _welcomeTurn() {
    final message = _welcomeMessage();
    return ChatTurn(id: message.id, role: 'assistant', text: message.text);
  }

  ChatMessage _welcomeMessage() {
    final text = healthCase != null
        ? 'Hai Anne. Berdasarkan analisis visual, ayam di **${healthCase!.cage}** menunjukkan perubahan perilaku yang perlu dikonfirmasi. Silakan periksa ayam secara langsung dan isi Form Suspection di bawah dengan mencentang gejala yang benar-benar terlihat. Selesaikan juga checklist observasi dan beri tahu saya bila ada perubahan kondisi.'
        : 'Halo Anne! Saya **Techi**. Saya dapat membantu mengevaluasi gejala, menyiapkan langkah operasional, dan membaca kondisi kandang. Apa yang ingin Anda periksa hari ini?';
    return ChatMessage(id: 'welcome-${widget.threadId}', role: 'assistant', text: text);
  }

  String _threadTitle() => healthCase != null
      ? '${healthCase!.cage} · ${healthCase!.topPossibility.name}'
      : 'Konsultasi operasional';

  void _persist(List<ChatTurn> turns) {
    _threads.upsert(StoredThread(
      id: widget.threadId,
      title: _threadTitle(),
      updatedAt: DateTime.now().toUtc().toIso8601String(),
      messages: [
        for (final turn in turns) ChatMessage(id: turn.id, role: turn.role, text: turn.text),
      ],
      checklist: _checked,
      selectedSymptoms: _selectedSymptoms,
      caseStatus: healthCase != null
          ? _caseStore.statusFor(healthCase!).name
          : 'pending',
    ));
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _submit(String text) {
    final clean = text.trim();
    if (clean.isEmpty || _client.busy) return;
    _inputController.clear();
    _client.sendMessage(text: clean, threadId: widget.threadId, caseId: healthCase?.id);
  }

  void _submitSuspicion() {
    if (healthCase == null ||
        _selectedSymptoms.isEmpty ||
        _client.busy) {
      return;
    }
    final observations = [
      for (final possibility in healthCase!.possibilities)
        (
          disease: possibility.name,
          baselineConfidence: possibility.confidence,
          symptoms: [
            for (final symptom in possibility.symptoms)
              (symptom: symptom, observed: _selectedSymptoms.contains(symptom)),
          ],
        ),
    ];
    _client.sendMessage(
      text: buildSuspicionPrompt(
        chickenId: healthCase!.chickenId,
        observations: observations,
      ),
      threadId: widget.threadId,
      caseId: healthCase!.id,
    );
  }

  @override
  Widget build(BuildContext context) {
    final suspicion = healthCase != null
        ? _caseStore.suspicionFor(healthCase!.id)
        : null;
    final isLandscape = MediaQuery.sizeOf(context).width > 900;

    final conversation = Expanded(
      child: Column(
        children: [
          if (healthCase != null) _buildCaseCard(context, suspicion),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: _client.turns.length + (_client.status == ChatStatus.submitted ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _client.turns.length) {
                  return const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('Techi sedang memeriksa kondisi...',
                        style: TextStyle(color: FutechiColors.mutedForeground)),
                  );
                }
                final turn = _client.turns[index];
                return _buildMessage(context, turn);
              },
            ),
          ),
          if (_client.error != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: FutechiColors.dangerSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(_client.error!,
                  style: const TextStyle(fontSize: 13, color: FutechiColors.danger)),
            ),
          if (healthCase != null && suspicion == null)
            _buildSuspectionForm(context),
          _buildComposer(context),
        ],
      ),
    );

    final body = isLandscape && _sidebarVisible
        ? Row(
            children: [
              SizedBox(width: 288, child: _buildSidebar(context, isPermanent: true)),
              Expanded(child: conversation),
            ],
          )
        : conversation;

    return Scaffold(
      backgroundColor: FutechiColors.background,
      appBar: AppBar(
        backgroundColor: FutechiColors.card,
        surfaceTintColor: FutechiColors.card,
        automaticallyImplyLeading: false,
        title: const Text('Techi AI',
            style: TextStyle(fontFamily: 'DMSans', fontWeight: FontWeight.w800)),
        centerTitle: true,
        actions: [
          if (isLandscape)
            IconButton(
              onPressed: () => setState(() => _sidebarVisible = !_sidebarVisible),
              icon: const Icon(Icons.view_sidebar_outlined),
            ),
        ],
      ),
      endDrawer: isLandscape ? null : _buildSidebar(context, isPermanent: false) as Widget,
      body: Builder(
        builder: (context) {
          // Restore from persistence exactly once per thread.
          WidgetsBinding.instance.addPostFrameCallback((_) => _restoreFromThread());
          return body;
        },
      ),
    );
  }

  Widget _buildSidebar(BuildContext context, {required bool isPermanent}) {
    final threads = _threads.threads;
    final drawer = Drawer(
      backgroundColor: FutechiColors.card,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextButton.icon(
              onPressed: () {
                if (Navigator.of(context).canPop()) Navigator.of(context).pop();
                Navigator.of(context)
                    .pushNamed(healthCase != null ? FutechiRoutes.history : FutechiRoutes.dashboard);
              },
              icon: const Icon(Icons.arrow_back, size: 18),
              label: Text(healthCase != null ? 'History' : 'Dashboard'),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () {
                final newId = DateTime.now().microsecondsSinceEpoch.toString();
                if (!isPermanent && Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
                Navigator.of(context).pushNamed('${FutechiRoutes.techi}/$newId');
              },
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('Percakapan baru'),
            ),
            const SizedBox(height: 24),
            const Text('PERCAKAPAN DI PERANGKAT INI',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: FutechiColors.mutedForeground)),
            const SizedBox(height: 8),
            for (final item in threads)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    backgroundColor: item.id == widget.threadId
                        ? FutechiColors.secondarySoft
                        : FutechiColors.card,
                    alignment: Alignment.centerLeft,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: () {
                    if (!isPermanent && Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    }
                    if (item.id != widget.threadId) {
                      Navigator.of(context)
                          .pushNamed('${FutechiRoutes.techi}/${item.id}');
                    }
                  },
                  child: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                ),
              ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: FutechiColors.successSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Saran AI tidak menggantikan pemeriksaan dokter hewan.',
                style: TextStyle(fontSize: 12, color: FutechiColors.success),
              ),
            ),
          ],
        ),
      ),
    );
    return drawer;
  }

  Widget _buildCaseCard(BuildContext context, SuspicionResult? suspicion) {
    final status = _caseStore.statusFor(healthCase!);
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: FutechiColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: FutechiColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${healthCase!.cage} · ${suspicion?.disease ?? "Pemeriksaan Gejala"}',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined, size: 16, color: FutechiColors.mutedForeground),
              const SizedBox(width: 6),
              Text(healthCase!.date,
                  style: const TextStyle(
                      fontSize: 14, color: FutechiColors.mutedForeground)),
              if (suspicion != null) ...[
                const SizedBox(width: 16),
                const Text('Kecocokan: ',
                    style: TextStyle(fontSize: 14, color: FutechiColors.mutedForeground)),
                Text('${suspicion.confidence}%',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: FutechiColors.primary)),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: FutechiColors.warningSoft,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              caseStatusLabel(status),
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: FutechiColors.warning),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: status == CaseStatus.sick
                        ? FutechiColors.danger
                        : FutechiColors.foreground,
                    side: BorderSide(
                        color: status == CaseStatus.sick
                            ? FutechiColors.danger
                            : FutechiColors.border),
                  ),
                  onPressed: () {
                    _caseStore.setStatus(healthCase!.id, CaseStatus.sick);
                    _persist(_client.turns);
                  },
                  child: const Text('Konfirmasi Sakit'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    _caseStore.setStatus(healthCase!.id, CaseStatus.healthy);
                    _persist(_client.turns);
                  },
                  child: const Text('Tandai Sehat'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(BuildContext context, ChatTurn turn) {
    final isSuspicionSubmission = isSuspicionSubmission(turn.text);
    final result = parseSuspicionResult(turn.text);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      alignment:
          turn.role == 'user' ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.82,
        ),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: turn.role == 'user'
                ? FutechiColors.primary
                : FutechiColors.card,
            borderRadius: BorderRadius.circular(16),
            border: turn.role == 'user'
                ? null
                : Border.all(color: FutechiColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isSuspicionSubmission)
                const Row(
                  children: [
                    Icon(Icons.stethoscope, size: 16, color: FutechiColors.onPrimary),
                    SizedBox(width: 8),
                    Text('Form Suspection dikirim',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
              if (!isSuspicionSubmission && !containsSuspicionBlock(turn.text))
                MarkdownBody(
                  data: turn.text,
                  selectable: true,
                  styleSheet: MarkdownStyleSheet(
                    p: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: turn.role == 'user'
                          ? FutechiColors.onPrimary
                          : FutechiColors.foreground,
                    ),
                    strong: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: turn.role == 'user'
                          ? FutechiColors.onPrimary
                          : FutechiColors.foreground,
                    ),
                  ),
                ),
              if (result != null) _buildResultCard(result),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultCard(SuspicionResult result) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        border: Border.all(color: FutechiColors.success),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: FutechiColors.successSoft,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.verified_outlined, size: 16, color: FutechiColors.success),
                    SizedBox(width: 8),
                    Text('HASIL PEMERIKSAAN TECHI',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: FutechiColors.success)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(result.disease,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800)),
                Text('Kecocokan ${result.confidence}%',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: FutechiColors.success)),
                const SizedBox(height: 12),
                Text(result.rationale,
                    style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Mitigasi yang disarankan',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                for (final item in result.mitigation)
                  Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 4),
                    child: Text('• $item',
                        style: const TextStyle(
                            fontSize: 14, color: FutechiColors.mutedForeground)),
                  ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: FutechiColors.warningSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Saran obat/penanganan',
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: FutechiColors.warning)),
                      const SizedBox(height: 4),
                      Text(result.medication,
                          style: const TextStyle(
                              fontSize: 14, color: FutechiColors.mutedForeground)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuspectionForm(BuildContext context) {
    final symptoms = suspicionSymptoms(healthCase!);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: FutechiColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: FutechiColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.stethoscope, color: FutechiColors.primary),
              SizedBox(width: 8),
              Text('Form Suspection',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Periksa ayam secara langsung. Centang setiap gejala yang benar-benar terlihat dan biarkan kosong bila tidak ditemukan.',
            style: TextStyle(fontSize: 13, color: FutechiColors.mutedForeground),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: FutechiColors.border),
              borderRadius: BorderRadius.circular(12),
            ),
            child: LayoutBuilder(builder: (context, constraints) {
              final twoColumns = constraints.maxWidth > 560;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final symptom in symptoms)
                    SizedBox(
                      width: twoColumns ? (constraints.maxWidth - 16 - 8) / 2 : double.infinity,
                      child: CheckboxListTile(
                        dense: true,
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        value: _selectedSymptoms.contains(symptom),
                        onChanged: (_) {
                          setState(() {
                            if (_selectedSymptoms.contains(symptom)) {
                              _selectedSymptoms = _selectedSymptoms
                                  .where((s) => s != symptom)
                                  .toList();
                            } else {
                              _selectedSymptoms = [..._selectedSymptoms, symptom];
                            }
                          });
                          _persist(_client.turns);
                        },
                        title: Text(symptom, style: const TextStyle(fontSize: 14)),
                      ),
                    ),
                ],
              );
            }),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _selectedSymptoms.isEmpty || _client.busy
                  ? null
                  : _submitSuspicion,
              icon: const Icon(Icons.checklist_outlined),
              label: const Text('Kirim Hasil Pemeriksaan'),
            ),
          ),
          if (_selectedSymptoms.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Center(
                child: Text(
                  'Centang setidaknya satu gejala untuk mengirim pemeriksaan.',
                  style: TextStyle(fontSize: 12, color: FutechiColors.mutedForeground),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildComposer(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, 16 + MediaQuery.paddingOf(context).bottom),
      decoration: const BoxDecoration(
        color: FutechiColors.card,
        border: Border(top: BorderSide(color: FutechiColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputController,
              minLines: 1,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Ketik pesan untuk Techi...',
                filled: true,
                fillColor: FutechiColors.background,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: FutechiColors.border),
                ),
              ),
              onSubmitted: _submit,
            ),
          ),
          const SizedBox(width: 12),
          _client.busy
              ? IconButton.filled(
                  onPressed: _client.stop,
                  icon: const Icon(Icons.stop),
                )
              : IconButton.filled(
                  onPressed: () => _submit(_inputController.text),
                  icon: const Icon(Icons.send),
                ),
        ],
      ),
    );
  }
}

/// Port of suspicionSymptoms: deduplicate + pseudo-deterministic shuffle.
List<String> suspicionSymptoms(HealthCase healthCase) {
  final unique = <String>{
    for (final p in healthCase.possibilities) ...p.symptoms,
  }.toList();
  int score(String text) {
    var acc = 7;
    for (final ch in (healthCase.id + text).codeUnits) {
      acc = (acc * 31 + ch) % 9973;
    }
    return acc;
  }
  unique.sort((a, b) => score(a).compareTo(score(b)));
  return unique;
}
