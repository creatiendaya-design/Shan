import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/budgets_table.dart';

part 'budget_dao.g.dart';

@DriftAccessor(tables: [Budgets])
class BudgetDao extends DatabaseAccessor<AppDatabase> with _$BudgetDaoMixin {
  BudgetDao(super.db);

  Stream<List<Budget>> watchByMonth(int year, int month) =>
      (select(budgets)
            ..where((b) => b.year.equals(year) & b.month.equals(month)))
          .watch();

  Future<List<Budget>> getByMonth(int year, int month) =>
      (select(budgets)
            ..where((b) => b.year.equals(year) & b.month.equals(month)))
          .get();

  Future<void> upsert(BudgetsCompanion entry) =>
      into(budgets).insertOnConflictUpdate(entry);

  Future<void> deleteBudget(String id) =>
      (delete(budgets)..where((b) => b.id.equals(id))).go();
}
