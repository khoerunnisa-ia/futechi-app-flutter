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
    // ChatClient otomatis memilih mode:
    //   - Direct LLM (OpenAI SSE) bila LLM_API_KEY terisi di .env
    //   - Backend proxy (FUTECHI_CHAT_URL/api/chat) bila LLM_API_KEY kosong
    _client = ChatClient();
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

  void _toggleSymptom(String symptom) {
    setState(() {
      if (_selectedSymptoms.contains(symptom)) {
        _selectedSymptoms = _selectedSymptoms.where((s) => s != symptom).toList();
      } else {
        _selectedSymptoms = [..._selectedSymptoms, symptom];
      }
    });
    _persist(_client.turns);
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

  /// Real (non-dummy) submit — kept for when the LLM/backend is wired up.
  // ignore: unused_element
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

    final showCaseCard = healthCase != null;
    final showLoading = _client.status == ChatStatus.submitted;
    final showForm = healthCase != null && suspicion == null;
    final turnOffset = showCaseCard ? 1 : 0;
    final conversation = Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(vertical: 12),
            itemCount: turnOffset +
                _client.turns.length +
                (showLoading ? 1 : 0) +
                (showForm ? 1 : 0),
            itemBuilder: (context, index) {
              if (showCaseCard && index == 0) {
                return _buildCaseCard(context, suspicion);
              }
              final turnIndex = index - turnOffset;
              if (turnIndex < _client.turns.length) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildMessage(context, _client.turns[turnIndex]),
                );
              }
              if (showLoading && turnIndex == _client.turns.length) {
                return const Padding(
                  padding: EdgeInsets.all(28),
                  child: Text('Techi sedang memeriksa kondisi...',
                      style: TextStyle(color: FutechiColors.mutedForeground)),
                );
              }
              return _buildSuspectionForm(context);
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
        _buildComposer(context),
      ],
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
        title: Text('Techi AI', style: Theme.of(context).textTheme.titleLarge),
        centerTitle: true,
        actions: [
          if (isLandscape)
            IconButton(
              onPressed: () => setState(() => _sidebarVisible = !_sidebarVisible),
              icon: const Icon(Icons.view_sidebar_outlined),
            ),
        ],
      ),
      endDrawer: isLandscape ? null : _buildSidebar(context, isPermanent: false),
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
            const SizedBox(height: 24),
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
            style: Theme.of(context).textTheme.titleLarge,
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
    final isSubmission = isSuspicionSubmission(turn.text);
    final hasBlock = !isSubmission && containsSuspicionBlock(turn.text);
    final result = hasBlock ? parseSuspicionResult(turn.text) : null;
    final isStreamingTurn = _client.busy && identical(turn, _client.turns.last);
    final markdownText = !hasBlock
        ? turn.text
        : result != null || isStreamingTurn
            ? stripSuspicionBlock(turn.text)
            : turn.text;
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
              if (isSubmission)
                const Row(
                  children: [
                    Icon(Icons.medical_services_outlined, size: 16, color: FutechiColors.onPrimary),
                    SizedBox(width: 8),
                    Text('Form Suspection dikirim',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: FutechiColors.onPrimary)),
                  ],
                ),
              if (!isSubmission && markdownText.isNotEmpty)
                MarkdownBody(
                  data: markdownText,
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
              if (hasBlock && result == null && isStreamingTurn)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('Techi sedang menyusun hasil pemeriksaan...',
                      style: TextStyle(
                          fontSize: 13, color: FutechiColors.mutedForeground)),
                ),
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
                    style: Theme.of(context).textTheme.titleLarge),
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
          Row(
            children: [
              const Icon(Icons.medical_services_outlined, color: FutechiColors.primary),
              const SizedBox(width: 8),
              Flexible(
                child: Text('Form Suspection',
                    style: Theme.of(context).textTheme.titleLarge),
              ),
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
                      child: Material(
                        color: FutechiColors.card,
                        borderRadius: BorderRadius.circular(8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => _toggleSymptom(symptom),
                          child: CheckboxListTile(
                            dense: true,
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: EdgeInsets.zero,
                            value: _selectedSymptoms.contains(symptom),
                            onChanged: (_) => _toggleSymptom(symptom),
                            title: Text(symptom, style: const TextStyle(fontSize: 14)),
                          ),
                        ),
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
                  : () => _submitSuspicionDummy(List.of(_selectedSymptoms)),
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

  /// Dummy mode for the inspection form (temporary until the LLM/backend
  /// endpoint is wired): mirrors the react-js flow exactly — a user turn is
  /// pushed, the assistant replies with a SUSPECTION_RESULT block, which is
  /// parsed and persisted into the case card.
  void _submitSuspicionDummy(List<String> observedSymptoms) {
    final disease = _pickDummyDisease(observedSymptoms);
    final confidence = _pickDummyConfidence(observedSymptoms);
    final result = SuspicionResult(
      disease: disease.name,
      confidence: confidence,
      rationale:
          'Hasil sementara (mode dummy): gejala yang kamu centang (${observedSymptoms.join(", ")}) paling cocok dengan pola ${disease.name}.',
      mitigation: List.of(disease.mitigation),
      medication: disease.medication,
      submittedAt: DateTime.now().toUtc().toIso8601String(),
    );
    final message = 'SUSPECTION_RESULT_START\n'
        '{"disease": "${result.disease}", "confidence": ${result.confidence}, '
        '"rationale": "${result.rationale}", '
        '"mitigation": [${result.mitigation.map((e) => '"$e"').join(", ")}], '
        '"medication": "${result.medication}"}\n'
        'SUSPECTION_RESULT_END';
    _client.reset([
      ..._client.turns,
      ChatTurn(role: 'user', text: '[FORM SUSPECTION] ${observedSymptoms.join(", ")}'),
      ChatTurn(role: 'assistant', text: message),
    ]);
    if (healthCase != null) {
      _caseStore.setSuspicionResult(healthCase!.id, result);
    }
    _persist(_client.turns);
  }

  static const List<_DummyDisease> _dummyDiseases = [
    _DummyDisease(
      name: 'Newcastle Disease (ND)',
      keywords: ['diare', 'hijau', 'putus kaki', 'torticollis', 'leher'],
      mitigation: [
        'Isolasi ayam yang menunjukkan gejala di kandang terpisah.',
        'Tingkatkan biosekuriti: desinfeksi alat, pakaian, dan area masuk.',
        'Pantau suhu kandang dan kepadatan populasi.',
      ],
      medication:
          'Belum ada obat spesifik ND; dukung dengan vitamin/elektrolit, dan wajib konsultasi dokter hewan sebelum pemberian apa pun.',
    ),
    _DummyDisease(
      name: 'Avian Influenza (AI)',
      keywords: ['napas', 'biru', 'bangkak', 'wattle', 'sianosis'],
      mitigation: [
        'Isolasi ayam yang menunjukkan gejala di kandang terpisah.',
        'Tingkatkan biosekuriti: desinfeksi alat, pakaian, dan area masuk.',
        'Batasi lalu lintas orang/peralatan antar kandang.',
      ],
      medication:
          'Tidak ada obat spesifik AI; dukung dengan vitamin/elektrolit, dan wajib konsultasi dokter hewan sebelum pemberian apa pun.',
    ),
    _DummyDisease(
      name: 'Infectious Bronchitis (IB)',
      keywords: ['berak', 'berjal', 'kering', 'debu'],
      mitigation: [
        'Perbaiki ventilasi dan kelembapan kandang.',
        'Sediakan air minum bersih dan ganti lebih sering.',
        'Isolasi ayam yang menunjukkan gejala pernapasan.',
      ],
      medication:
          'Dukung dengan vitamin/elektrolit, dan wajib konsultasi dokter hewan sebelum pemberian apa pun.',
    ),
  ];

  _DummyDisease _pickDummyDisease(List<String> observed) {
    final text = observed.join(' ').toLowerCase();
    for (final disease in _dummyDiseases) {
      for (final keyword in disease.keywords) {
        if (text.contains(keyword)) return disease;
      }
    }
    return _dummyDiseases.last;
  }

  int _pickDummyConfidence(List<String> observed) {
    switch (observed.length) {
      case 0:
        return 60;
      case 1:
        return 72;
      case 2:
        return 82;
      default:
        return 90;
    }
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

class _DummyDisease {
  const _DummyDisease({
    required this.name,
    required this.keywords,
    required this.mitigation,
    required this.medication,
  });

  final String name;
  final List<String> keywords;
  final List<String> mitigation;
  final String medication;
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
