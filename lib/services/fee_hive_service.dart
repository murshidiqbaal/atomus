import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/dummy_data.dart';

class FeeHiveService {
  static const String _feeRecordsBox = 'fee_records';
  static const String _feeStructureBox = 'fee_structure';
  static const String _paymentHistoryBox = 'fee_payment_history';

  // Singleton
  static final FeeHiveService _instance = FeeHiveService._internal();
  factory FeeHiveService() => _instance;
  FeeHiveService._internal();

  bool _initialized = false;
  bool get isInitialized => _initialized;

  Future<void> initBoxes() async {
    if (_initialized) return;
    await Future.wait([
      _openBox(_feeRecordsBox),
      _openBox(_feeStructureBox),
      _openBox(_paymentHistoryBox),
    ]);
    _initialized = true;
  }

  Future<Box<String>> _openBox(String name) async {
    if (!Hive.isBoxOpen(name)) {
      return await Hive.openBox<String>(name);
    }
    return Hive.box<String>(name);
  }

  Box<String> _getBox(String name) {
    if (!Hive.isBoxOpen(name)) {
      throw StateError('Hive box $name is not open. Call initBoxes() first.');
    }
    return Hive.box<String>(name);
  }

  // ── Fee Records (term-wise) ─────────────────────────────────────
  Future<void> saveFeeRecords(List<FeeRecord> records) async {
    final box = _getBox(_feeRecordsBox);
    final data = records.map((r) => {
      'id': r.id,
      'title': r.title,
      'amount': r.amount,
      'dueDate': r.dueDate.toIso8601String(),
      'isPaid': r.isPaid,
      'receiptId': r.receiptId,
      'status': r.status,
      'amountPaid': r.amountPaid,
      'paymentDate': r.paymentDate?.toIso8601String(),
    }).toList();
    await box.put('records', jsonEncode(data));
    await box.put('cached_at', DateTime.now().toIso8601String());
  }

  List<FeeRecord>? getCachedFeeRecords() {
    final box = _getBox(_feeRecordsBox);
    final raw = box.get('records');
    if (raw == null) return null;

    // Check freshness (cache valid for 30 minutes)
    final cachedAt = box.get('cached_at');
    if (cachedAt != null) {
      final ts = DateTime.tryParse(cachedAt);
      if (ts != null && DateTime.now().difference(ts).inMinutes > 30) {
        return null; // stale
      }
    }

    final list = jsonDecode(raw) as List;
    return list.map((m) {
      final map = m as Map<String, dynamic>;
      return FeeRecord(
        id: map['id']?.toString(),
        title: map['title'] ?? '',
        amount: (map['amount'] ?? 0).toDouble(),
        dueDate: DateTime.tryParse(map['dueDate'] ?? '') ?? DateTime.now(),
        isPaid: map['isPaid'] ?? false,
        receiptId: map['receiptId'] ?? '',
        status: map['status'],
        amountPaid: (map['amountPaid'] ?? 0).toDouble(),
        paymentDate: map['paymentDate'] != null
            ? DateTime.tryParse(map['paymentDate'])
            : null,
      );
    }).toList();
  }

  // ── Fee Structure Metadata ──────────────────────────────────────
  Future<void> saveFeeStructure(Map<String, dynamic> structure) async {
    final box = _getBox(_feeStructureBox);
    await box.put('structure', jsonEncode(structure));
  }

  Map<String, dynamic>? getCachedFeeStructure() {
    final box = _getBox(_feeStructureBox);
    final raw = box.get('structure');
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  // ── Payment History ─────────────────────────────────────────────
  Future<void> savePaymentHistory(List<Map<String, dynamic>> transactions) async {
    final box = _getBox(_paymentHistoryBox);
    await box.put('history', jsonEncode(transactions));
    await box.put('cached_at', DateTime.now().toIso8601String());
  }

  List<Map<String, dynamic>>? getCachedPaymentHistory() {
    final box = _getBox(_paymentHistoryBox);
    final raw = box.get('history');
    if (raw == null) return null;

    final cachedAt = box.get('cached_at');
    if (cachedAt != null) {
      final ts = DateTime.tryParse(cachedAt);
      if (ts != null && DateTime.now().difference(ts).inMinutes > 30) {
        return null;
      }
    }

    final list = jsonDecode(raw) as List;
    return list.map((e) => e as Map<String, dynamic>).toList();
  }

  // ── Clear all ───────────────────────────────────────────────────
  Future<void> clearAll() async {
    await _getBox(_feeRecordsBox).clear();
    await _getBox(_feeStructureBox).clear();
    await _getBox(_paymentHistoryBox).clear();
  }
}
