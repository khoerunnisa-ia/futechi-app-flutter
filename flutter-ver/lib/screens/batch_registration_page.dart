import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app/theme.dart';
import '../data/batch_data.dart';
import '../widgets/case_card.dart';

class BatchRegistrationPage extends StatefulWidget {
  const BatchRegistrationPage({super.key});

  @override
  State<BatchRegistrationPage> createState() => _BatchRegistrationPageState();
}

class _BatchRegistrationPageState extends State<BatchRegistrationPage> {
  final _formKey = GlobalKey<FormState>();

  late final String _generatedBatchId;
  final TextEditingController _batchIdController = TextEditingController();
  final TextEditingController _chickenCountController = TextEditingController(text: '1000');
  final TextEditingController _ageController = TextEditingController(text: '0');

  String? _selectedBreed;
  DateTime _startDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _generatedBatchId = BatchStore.instance.generateNextBatchId();
    _batchIdController.text = _generatedBatchId;
  }

  @override
  void dispose() {
    _batchIdController.dispose();
    _chickenCountController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Pilih Tanggal Mulai Batch',
      confirmText: 'Pilih',
      cancelText: 'Batal',
    );
    if (picked != null) {
      setState(() => _startDate = picked);
    }
  }

  void _saveBatch() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedBreed == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan pilih jenis ayam')),
      );
      return;
    }

    final count = int.tryParse(_chickenCountController.text.trim()) ?? 1000;
    final age = int.tryParse(_ageController.text.trim()) ?? 0;

    final newBatch = PoultryBatch(
      id: _generatedBatchId.toLowerCase(),
      name: _generatedBatchId,
      breed: _selectedBreed!,
      chickenCount: count,
      startDate: _startDate,
      ageInDays: age,
      location: 'Jl. Bendul Merisi Selatan XI No.51, Bendul Merisi, Kec. Wonocolo, Surabaya',
      isActive: true,
    );

    BatchStore.instance.addBatch(newBatch);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Batch $_generatedBatchId berhasil disimpan!'),
        backgroundColor: FutechiColors.success,
      ),
    );

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: FutechiColors.background,
      appBar: AppBar(
        backgroundColor: FutechiColors.card,
        surfaceTintColor: FutechiColors.card,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: FutechiColors.foreground),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Kembali',
        ),
        title: Text(
          'Detail Laporan',
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: const Color(0xFF9E6B20), // Warm amber-gold title matching mockup
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Registrasi Batch',
                style: textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: FutechiColors.foreground,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Masukkan detail operasional untuk memantau siklus hidup dan kesehatan batch ayam baru di fasilitas Anda.',
                style: textTheme.bodyMedium?.copyWith(
                  color: FutechiColors.mutedForeground,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 24),
              FutechiCard(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Field 1: Nama / ID Batch (Otomatis & Read-Only)
                      _buildLabel('Nama / ID Batch'),
                      TextFormField(
                        controller: _batchIdController,
                        readOnly: true,
                        style: textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: FutechiColors.foreground,
                        ),
                        decoration: _inputDecoration(
                          hintText: 'e.g. BATCH-2024-A',
                          fillColor: FutechiColors.secondarySoft.withAlpha(80),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Field 2: Jumlah Ayam
                      _buildLabel('Jumlah Ayam'),
                      TextFormField(
                        controller: _chickenCountController,
                        keyboardType: TextInputType.number,
                        style: textTheme.bodyMedium?.copyWith(
                          color: FutechiColors.foreground,
                        ),
                        decoration: _inputDecoration(hintText: '1000'),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Jumlah ayam wajib diisi';
                          }
                          final parsed = int.tryParse(value.trim());
                          if (parsed == null || parsed <= 0) {
                            return 'Masukkan jumlah ayam yang valid';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),

                      // Field 3: Jenis Ayam
                      _buildLabel('Jenis Ayam'),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedBreed,
                        style: textTheme.bodyMedium?.copyWith(
                          color: FutechiColors.foreground,
                        ),
                        decoration: _inputDecoration(
                          hintText: 'Pilih jenis unggas',
                          prefixIcon: const Icon(
                            Icons.category_outlined,
                            size: 20,
                            color: FutechiColors.mutedForeground,
                          ),
                        ),
                        icon: const Icon(Icons.arrow_drop_down, color: FutechiColors.mutedForeground),
                        isExpanded: true,
                        items: [
                          for (final breed in BatchStore.availableBreeds)
                            DropdownMenuItem(
                              value: breed,
                              child: Text(breed, overflow: TextOverflow.ellipsis),
                            ),
                        ],
                        onChanged: (val) {
                          setState(() => _selectedBreed = val);
                        },
                        validator: (value) =>
                            value == null ? 'Pilih salah satu jenis ayam' : null,
                      ),
                      const SizedBox(height: 18),

                      // Field 4: Tanggal Mulai
                      _buildLabel('Tanggal Mulai'),
                      InkWell(
                        onTap: _pickStartDate,
                        borderRadius: BorderRadius.circular(12),
                        child: IgnorePointer(
                          child: TextFormField(
                            key: ValueKey(_startDate),
                            initialValue: DateFormat('MM/dd/yyyy').format(_startDate),
                            style: textTheme.bodyMedium?.copyWith(
                              color: FutechiColors.foreground,
                            ),
                            decoration: _inputDecoration(
                              hintText: 'MM/DD/YYYY',
                              prefixIcon: const Icon(
                                Icons.calendar_today_outlined,
                                size: 18,
                                color: FutechiColors.mutedForeground,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Field 5: Umur Saat Masuk (Hari)
                      _buildLabel('Umur Saat Masuk (Hari)'),
                      TextFormField(
                        controller: _ageController,
                        keyboardType: TextInputType.number,
                        style: textTheme.bodyMedium?.copyWith(
                          color: FutechiColors.foreground,
                        ),
                        decoration: _inputDecoration(
                          hintText: '0',
                          prefixIcon: const Icon(
                            Icons.hourglass_empty_outlined,
                            size: 18,
                            color: FutechiColors.mutedForeground,
                          ),
                          suffixText: 'Hari',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Umur wajib diisi';
                          }
                          if (int.tryParse(value.trim()) == null) {
                            return 'Masukkan angka umur yang valid';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      const Divider(color: FutechiColors.border, height: 1),
                      const SizedBox(height: 24),

                      // Submit Button: Simpan Batch
                      Center(
                        child: SizedBox(
                          width: 220,
                          height: 48,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFB87828), // Golden brown per mockup, harmonious with Futechi
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
                            ),
                            onPressed: _saveBatch,
                            child: Text(
                              'Simpan Batch',
                              style: textTheme.labelLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: FutechiColors.foreground,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    Widget? prefixIcon,
    String? suffixText,
    Color? fillColor,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: FutechiColors.mutedForeground, fontSize: 14),
      prefixIcon: prefixIcon,
      suffixText: suffixText,
      suffixStyle: const TextStyle(
        fontWeight: FontWeight.w600,
        color: FutechiColors.foreground,
        fontSize: 14,
      ),
      filled: true,
      fillColor: fillColor ?? FutechiColors.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: FutechiColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: FutechiColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: FutechiColors.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: FutechiColors.danger, width: 1.5),
      ),
    );
  }
}
