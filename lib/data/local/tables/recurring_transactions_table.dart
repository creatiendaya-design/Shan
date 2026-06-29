import 'package:drift/drift.dart';

class RecurringTransactions extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get type => text()(); // expense | income
  IntColumn get amountCents => integer()();
  TextColumn get accountId => text()();
  TextColumn get categoryId => text().nullable()();
  TextColumn get frequency => text()(); // daily | weekly | monthly | yearly
  IntColumn get nextDueDateMs => integer()();
  TextColumn get note => text().nullable()();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
