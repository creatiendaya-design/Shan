import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/investments_table.dart';

part 'investment_dao.g.dart';

@DriftAccessor(tables: [Investments])
class InvestmentDao extends DatabaseAccessor<AppDatabase> with _$InvestmentDaoMixin {
  InvestmentDao(super.db);

  Stream<List<Investment>> watchAll() =>
      (select(investments)..orderBy([(i) => OrderingTerm.desc(i.createdAt)])).watch();

  Future<void> insertInvestment(InvestmentsCompanion entry) => into(investments).insert(entry);

  Future<void> updateInvestment(InvestmentsCompanion entry) =>
      (update(investments)..where((i) => i.id.equals(entry.id.value))).write(entry);

  Future<void> deleteInvestment(String id) =>
      (delete(investments)..where((i) => i.id.equals(id))).go();
}
