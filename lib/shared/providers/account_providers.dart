import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/local/app_database.dart';
import 'database_provider.dart';

final accountBalancesProvider =
    FutureProvider.autoDispose<Map<String, int>>((ref) async {
  final db = ref.watch(databaseProvider);
  final accs = await db.accountDao.getAll();
  final balances = <String, int>{};
  for (final a in accs) {
    balances[a.id] = await db.accountDao.getBalanceCents(a.id);
  }
  return balances;
});

final accountBalanceProvider =
    FutureProvider.autoDispose.family<int, String>((ref, accountId) async {
  final db = ref.watch(databaseProvider);
  return db.accountDao.getBalanceCents(accountId);
});

final accountsStreamProvider = StreamProvider.autoDispose<List<Account>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.accountDao.watchAll();
});
