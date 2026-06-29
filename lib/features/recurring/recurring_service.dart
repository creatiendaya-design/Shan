import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../data/local/app_database.dart';
import '../notifications/notification_service.dart';

const _uuid = Uuid();

DateTime _nextDate(DateTime from, String frequency) {
  switch (frequency) {
    case 'daily':   return DateTime(from.year, from.month, from.day + 1);
    case 'weekly':  return DateTime(from.year, from.month, from.day + 7);
    case 'yearly':  return DateTime(from.year + 1, from.month, from.day);
    default:        return DateTime(from.year, from.month + 1, from.day); // monthly
  }
}

/// Processes all overdue recurring transactions, creates real transactions,
/// and advances their next due date. Returns count of transactions created.
Future<int> applyDueRecurring(AppDatabase db) async {
  final due = await db.recurringTransactionDao.getDue();
  int count = 0;

  for (final r in due) {
    final now = DateTime.now().millisecondsSinceEpoch;
    var dueDate = DateTime.fromMillisecondsSinceEpoch(r.nextDueDateMs);

    // Create one transaction per missed cycle
    while (!dueDate.isAfter(DateTime.now())) {
      await db.transactionDao.insertTransaction(TransactionsCompanion(
        id: Value(_uuid.v4()),
        type: Value(r.type),
        amountCents: Value(r.amountCents),
        accountId: Value(r.accountId),
        categoryId: Value(r.categoryId),
        date: Value(dueDate.millisecondsSinceEpoch),
        note: Value(r.note ?? r.name),
        createdAt: Value(now),
        updatedAt: Value(now),
      ));
      count++;
      dueDate = _nextDate(dueDate, r.frequency);
    }

    // Advance next due date
    await db.recurringTransactionDao.updateRecurring(
      RecurringTransactionsCompanion(
        id: Value(r.id),
        nextDueDateMs: Value(dueDate.millisecondsSinceEpoch),
      ),
    );
  }

  // Re-schedule notifications after processing
  final all = await db.recurringTransactionDao.watchAll().first;
  await rescheduleRecurringNotifications(all);

  return count;
}
