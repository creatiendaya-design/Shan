import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/debts_table.dart';

part 'debt_dao.g.dart';

@DriftAccessor(tables: [Debts])
class DebtDao extends DatabaseAccessor<AppDatabase> with _$DebtDaoMixin {
  DebtDao(super.db);

  Stream<List<Debt>> watchAll() =>
      (select(debts)..orderBy([(d) => OrderingTerm(expression: d.createdAt)])).watch();

  Future<void> insertDebt(DebtsCompanion entry) => into(debts).insert(entry);

  Future<void> updateDebt(DebtsCompanion entry) =>
      (update(debts)..where((d) => d.id.equals(entry.id.value))).write(entry);

  Future<void> deleteDebt(String id) =>
      (delete(debts)..where((d) => d.id.equals(id))).go();
}
