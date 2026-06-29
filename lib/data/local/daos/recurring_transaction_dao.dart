import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/recurring_transactions_table.dart';

part 'recurring_transaction_dao.g.dart';

@DriftAccessor(tables: [RecurringTransactions])
class RecurringTransactionDao extends DatabaseAccessor<AppDatabase>
    with _$RecurringTransactionDaoMixin {
  RecurringTransactionDao(super.db);

  Stream<List<RecurringTransaction>> watchAll() =>
      (select(recurringTransactions)
            ..orderBy([(r) => OrderingTerm(expression: r.nextDueDateMs)]))
          .watch();

  Future<List<RecurringTransaction>> getDue() =>
      (select(recurringTransactions)
            ..where((r) =>
                r.active.equals(true) &
                r.nextDueDateMs.isSmallerOrEqualValue(
                    DateTime.now().millisecondsSinceEpoch)))
          .get();

  Future<void> insertRecurring(RecurringTransactionsCompanion e) =>
      into(recurringTransactions).insert(e);

  Future<void> updateRecurring(RecurringTransactionsCompanion e) =>
      (update(recurringTransactions)..where((r) => r.id.equals(e.id.value)))
          .write(e);

  Future<void> deleteRecurring(String id) =>
      (delete(recurringTransactions)..where((r) => r.id.equals(id))).go();
}
