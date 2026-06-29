import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/transactions_table.dart';

part 'transaction_dao.g.dart';

@DriftAccessor(tables: [Transactions])
class TransactionDao extends DatabaseAccessor<AppDatabase>
    with _$TransactionDaoMixin {
  TransactionDao(super.db);

  Stream<List<Transaction>> watchByMonth(int year, int month) {
    final start = DateTime(year, month).millisecondsSinceEpoch;
    final end = DateTime(year, month + 1).millisecondsSinceEpoch;
    return (select(transactions)
          ..where((t) => t.date.isBetweenValues(start, end))
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .watch();
  }

  Future<List<Transaction>> getAll() =>
      (select(transactions)
            ..orderBy([(t) => OrderingTerm.desc(t.date)]))
          .get();

  Future<void> insertTransaction(TransactionsCompanion entry) =>
      into(transactions).insert(entry);

  Future<void> updateTransaction(TransactionsCompanion entry) =>
      (update(transactions)..where((t) => t.id.equals(entry.id.value)))
          .write(entry);

  Future<void> deleteTransaction(String id) =>
      (delete(transactions)..where((t) => t.id.equals(id))).go();

  Future<int> sumByTypeAndMonth(String type, int year, int month) async {
    final start = DateTime(year, month).millisecondsSinceEpoch;
    final end = DateTime(year, month + 1).millisecondsSinceEpoch;
    final expr = transactions.amountCents.sum();
    final result = await (selectOnly(transactions)
          ..addColumns([expr])
          ..where(transactions.type.equals(type) &
              transactions.date.isBetweenValues(start, end)))
        .map((r) => r.read(expr) ?? 0)
        .getSingle();
    return result;
  }

  Future<Map<String, int>> sumByCategoryAndMonth(int year, int month) async {
    final start = DateTime(year, month).millisecondsSinceEpoch;
    final end = DateTime(year, month + 1).millisecondsSinceEpoch;
    final expr = transactions.amountCents.sum();
    final rows = await (selectOnly(transactions)
          ..addColumns([transactions.categoryId, expr])
          ..where(transactions.type.equals('expense') &
              transactions.date.isBetweenValues(start, end))
          ..groupBy([transactions.categoryId]))
        .get();

    return {
      for (final r in rows)
        if (r.read(transactions.categoryId) != null)
          r.read(transactions.categoryId)!: r.read(expr) ?? 0
    };
  }
}
