import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/savings_goals_table.dart';

part 'savings_goal_dao.g.dart';

@DriftAccessor(tables: [SavingsGoals])
class SavingsGoalDao extends DatabaseAccessor<AppDatabase> with _$SavingsGoalDaoMixin {
  SavingsGoalDao(super.db);

  Stream<List<SavingsGoal>> watchAll() =>
      (select(savingsGoals)..orderBy([(g) => OrderingTerm(expression: g.createdAt)])).watch();

  Future<void> insert(SavingsGoalsCompanion entry) => into(savingsGoals).insert(entry);

  Future<void> updateGoal(SavingsGoalsCompanion entry) =>
      (update(savingsGoals)..where((g) => g.id.equals(entry.id.value))).write(entry);

  Future<void> deleteGoal(String id) =>
      (delete(savingsGoals)..where((g) => g.id.equals(id))).go();
}
