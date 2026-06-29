import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/local/app_database.dart';
import '../../features/streak/streak_service.dart';
import 'database_provider.dart';

// ── Meta de ingreso mensual ───────────────────────────────────────────────────

class IncomeGoalNotifier extends AsyncNotifier<int> {
  static const _key = 'income_goal_cents';

  @override
  Future<int> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_key) ?? 0;
  }

  Future<void> setGoal(int cents) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, cents);
    state = AsyncData(cents);
  }
}

final incomeGoalProvider =
    AsyncNotifierProvider<IncomeGoalNotifier, int>(IncomeGoalNotifier.new);

final streakProvider = FutureProvider.autoDispose<StreakData>((ref) {
  return StreakService.load();
});

final categoriesProvider = StreamProvider<List<Category>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.categoryDao.watchAll();
});

final expenseCategoriesProvider = FutureProvider<List<Category>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.categoryDao.getByKind('expense');
});

final incomeCategoriesProvider = FutureProvider<List<Category>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.categoryDao.getByKind('income');
});

final accountsProvider = StreamProvider<List<Account>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.accountDao.watchAll();
});

final transactionsByMonthProvider =
    StreamProvider.family<List<Transaction>, (int, int)>((ref, params) {
  final db = ref.watch(databaseProvider);
  return db.transactionDao.watchByMonth(params.$1, params.$2);
});

final monthlySummaryProvider =
    FutureProvider.family<(int, int), (int, int)>((ref, params) async {
  final db = ref.watch(databaseProvider);
  final income =
      await db.transactionDao.sumByTypeAndMonth('income', params.$1, params.$2);
  final expense = await db.transactionDao
      .sumByTypeAndMonth('expense', params.$1, params.$2);
  return (income, expense);
});

final spendingByCategoryProvider =
    FutureProvider.autoDispose.family<Map<String, int>, (int, int)>(
        (ref, params) async {
  final db = ref.watch(databaseProvider);
  return db.transactionDao.sumByCategoryAndMonth(params.$1, params.$2);
});

/// Sum of real balances across all active accounts.
final totalBalanceProvider = FutureProvider.autoDispose<int>((ref) async {
  final db = ref.watch(databaseProvider);
  final accs = await db.accountDao.getAll();
  int total = 0;
  for (final a in accs) {
    total += await db.accountDao.getBalanceCents(a.id);
  }
  return total;
});

/// Upcoming payments in the next [days] days (recurring + unpaid debts).
final upcomingPaymentsProvider =
    FutureProvider.autoDispose<List<UpcomingPayment>>((ref) async {
  final db = ref.watch(databaseProvider);
  final now = DateTime.now();
  final cutoff = now.add(const Duration(days: 7));
  final result = <UpcomingPayment>[];

  // Recurring
  final recurring = await db.recurringTransactionDao.watchAll().first;
  for (final r in recurring) {
    if (!r.active) continue;
    final due = DateTime.fromMillisecondsSinceEpoch(r.nextDueDateMs);
    if (due.isBefore(cutoff)) {
      result.add(UpcomingPayment(
        name: r.name,
        amountCents: r.amountCents,
        dueDate: due,
        kind: 'recurring',
        isExpense: r.type == 'expense',
      ));
    }
  }

  // Debts
  final debts = await db.debtDao.watchAll().first;
  for (final d in debts) {
    if (d.paid || d.dueDateMs == null) continue;
    final due = DateTime.fromMillisecondsSinceEpoch(d.dueDateMs!);
    if (due.isBefore(cutoff)) {
      result.add(UpcomingPayment(
        name: d.name,
        amountCents: d.amountCents,
        dueDate: due,
        kind: 'debt',
        isExpense: d.direction == 'i_owe',
      ));
    }
  }

  result.sort((a, b) => a.dueDate.compareTo(b.dueDate));
  return result;
});

class UpcomingPayment {
  final String name;
  final int amountCents;
  final DateTime dueDate;
  final String kind; // 'recurring' | 'debt'
  final bool isExpense;

  const UpcomingPayment({
    required this.name,
    required this.amountCents,
    required this.dueDate,
    required this.kind,
    required this.isExpense,
  });

  bool get isOverdue => dueDate.isBefore(DateTime.now());
}
