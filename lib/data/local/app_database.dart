import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'tables/accounts_table.dart';
import 'tables/categories_table.dart';
import 'tables/transactions_table.dart';
import 'tables/budgets_table.dart';
import 'tables/debts_table.dart';
import 'tables/investments_table.dart';
import 'tables/savings_goals_table.dart';
import 'tables/recurring_transactions_table.dart';
import 'daos/account_dao.dart';
import 'daos/budget_dao.dart';
import 'daos/category_dao.dart';
import 'daos/debt_dao.dart';
import 'daos/investment_dao.dart';
import 'daos/savings_goal_dao.dart';
import 'daos/transaction_dao.dart';
import 'daos/recurring_transaction_dao.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Accounts, Categories, Transactions, Budgets,
    Debts, Investments, SavingsGoals, RecurringTransactions,
  ],
  daos: [
    AccountDao, BudgetDao, CategoryDao, DebtDao,
    InvestmentDao, SavingsGoalDao, TransactionDao, RecurringTransactionDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(debts);
            await m.createTable(investments);
            await m.createTable(savingsGoals);
          }
          if (from < 3) {
            await m.createTable(recurringTransactions);
          }
        },
      );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'shannon.db'));
    return NativeDatabase.createInBackground(file);
  });
}
