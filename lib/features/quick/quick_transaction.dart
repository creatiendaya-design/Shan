import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class QuickTransaction {
  final String id;
  final String name;
  final int amountCents;
  final String type; // 'expense' | 'income'
  final String accountId;
  final String? categoryId;

  const QuickTransaction({
    required this.id,
    required this.name,
    required this.amountCents,
    required this.type,
    required this.accountId,
    this.categoryId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'amountCents': amountCents,
        'type': type,
        'accountId': accountId,
        'categoryId': categoryId,
      };

  factory QuickTransaction.fromJson(Map<String, dynamic> j) => QuickTransaction(
        id: j['id'] as String,
        name: j['name'] as String,
        amountCents: j['amountCents'] as int,
        type: j['type'] as String,
        accountId: j['accountId'] as String,
        categoryId: j['categoryId'] as String?,
      );
}

class QuickTransactionNotifier extends AsyncNotifier<List<QuickTransaction>> {
  static const _key = 'quick_transactions';

  @override
  Future<List<QuickTransaction>> build() => _load();

  Future<List<QuickTransaction>> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => QuickTransaction.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> add(QuickTransaction qt) async {
    final current = state.valueOrNull ?? [];
    final updated = [...current, qt];
    await _save(updated);
    state = AsyncData(updated);
  }

  Future<void> remove(String id) async {
    final current = state.valueOrNull ?? [];
    final updated = current.where((q) => q.id != id).toList();
    await _save(updated);
    state = AsyncData(updated);
  }

  Future<void> _save(List<QuickTransaction> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(list.map((e) => e.toJson()).toList()));
  }
}

final quickTransactionProvider =
    AsyncNotifierProvider<QuickTransactionNotifier, List<QuickTransaction>>(
        QuickTransactionNotifier.new);
