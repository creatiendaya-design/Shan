import 'package:drift/drift.dart';
import 'categories_table.dart';

class Budgets extends Table {
  TextColumn get id => text()();
  IntColumn get year => integer()();
  IntColumn get month => integer()(); // 1-12
  TextColumn get categoryId =>
      text().nullable().references(Categories, #id)();
  IntColumn get limitCents => integer()();
  TextColumn get currency => text().withDefault(const Constant('USD'))();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
        {year, month, categoryId}
      ];
}
