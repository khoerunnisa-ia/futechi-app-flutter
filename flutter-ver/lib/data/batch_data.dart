import 'dart:math';
import 'package:flutter/foundation.dart';

class PoultryBatch {
  final String id;
  final String name;
  final String breed;
  final int chickenCount;
  final DateTime startDate;
  final int ageInDays;
  final String location;
  final bool isActive;

  PoultryBatch({
    required this.id,
    required this.name,
    required this.breed,
    required this.chickenCount,
    required this.startDate,
    required this.ageInDays,
    required this.location,
    this.isActive = true,
  });

  PoultryBatch copyWith({
    String? id,
    String? name,
    String? breed,
    int? chickenCount,
    DateTime? startDate,
    int? ageInDays,
    String? location,
    bool? isActive,
  }) {
    return PoultryBatch(
      id: id ?? this.id,
      name: name ?? this.name,
      breed: breed ?? this.breed,
      chickenCount: chickenCount ?? this.chickenCount,
      startDate: startDate ?? this.startDate,
      ageInDays: ageInDays ?? this.ageInDays,
      location: location ?? this.location,
      isActive: isActive ?? this.isActive,
    );
  }
}

class BatchStore extends ChangeNotifier {
  BatchStore._() {
    _initDefaultBatches();
  }

  static final BatchStore instance = BatchStore._();

  static const List<String> availableBreeds = [
    'Ayam Arab (Gold Fayoumi)',
    'Ayam Elba',
    'Ayam KUB (Kampung Unggul Balitbangtan)',
  ];

  final List<PoultryBatch> _batches = [];
  String _selectedBatchId = 'batch-24';

  List<PoultryBatch> get batches => List.unmodifiable(_batches);

  PoultryBatch get selectedBatch {
    return _batches.firstWhere(
      (b) => b.id == _selectedBatchId,
      orElse: () => _batches.isNotEmpty ? _batches.first : _defaultFallbackBatch,
    );
  }

  void _initDefaultBatches() {
    _batches.addAll([
      PoultryBatch(
        id: 'batch-24',
        name: 'Batch #24',
        breed: 'Ayam Arab (Gold Fayoumi)',
        chickenCount: 1240,
        startDate: DateTime.now().subtract(const Duration(days: 65)),
        ageInDays: 65,
        location: 'Jl. Bendul Merisi Selatan XI No.51, Bendul Merisi, Kec. Wonocolo, Surabaya',
        isActive: true,
      ),
      PoultryBatch(
        id: 'batch-23',
        name: 'Batch #23',
        breed: 'Ayam Elba',
        chickenCount: 1180,
        startDate: DateTime.now().subtract(const Duration(days: 75)),
        ageInDays: 75,
        location: 'Jl. Bendul Merisi Selatan XI No.51, Bendul Merisi, Kec. Wonocolo, Surabaya',
        isActive: false,
      ),
      PoultryBatch(
        id: 'batch-22',
        name: 'Batch #22',
        breed: 'Ayam KUB (Kampung Unggul Balitbangtan)',
        chickenCount: 1050,
        startDate: DateTime.now().subtract(const Duration(days: 80)),
        ageInDays: 80,
        location: 'Jl. Bendul Merisi Selatan XI No.51, Bendul Merisi, Kec. Wonocolo, Surabaya',
        isActive: false,
      ),
    ]);
  }

  static final PoultryBatch _defaultFallbackBatch = PoultryBatch(
    id: 'batch-default',
    name: 'Batch #24',
    breed: 'Ayam Arab (Gold Fayoumi)',
    chickenCount: 1240,
    startDate: DateTime.now().subtract(const Duration(days: 65)),
    ageInDays: 65,
    location: 'Jl. Bendul Merisi Selatan XI No.51, Bendul Merisi, Kec. Wonocolo, Surabaya',
    isActive: true,
  );

  void selectBatch(String id) {
    if (_selectedBatchId != id) {
      _selectedBatchId = id;
      notifyListeners();
    }
  }

  /// Menghasilkan Nama / ID Batch berikutnya secara otomatis:
  /// Incremental dari batch terakhir + random alphanumeric code.
  String generateNextBatchId() {
    int maxNumber = 24;
    final regex = RegExp(r'\d+');
    for (final b in _batches) {
      final match = regex.firstMatch(b.name);
      if (match != null) {
        final val = int.tryParse(match.group(0)!) ?? 0;
        if (val > maxNumber) maxNumber = val;
      }
    }
    final nextNumber = maxNumber + 1;
    final randomSuffix = _generateRandomCode(4);
    return 'BATCH-$nextNumber-$randomSuffix';
  }

  String _generateRandomCode(int length) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rnd = Random();
    return String.fromCharCodes(
      Iterable.generate(length, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))),
    );
  }

  void addBatch(PoultryBatch newBatch) {
    _batches.insert(0, newBatch);
    _selectedBatchId = newBatch.id;
    notifyListeners();
  }
}
