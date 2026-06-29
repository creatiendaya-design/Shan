import 'package:drift/drift.dart';

class SavingsGoals extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get targetCents => integer()();
  IntColumn get savedCents => integer().withDefault(const Constant(0))();
  TextColumn get currency => text().withDefault(const Constant('PEN'))();
  TextColumn get emoji => text().withDefault(const Constant('🎯'))();
  IntColumn get deadlineMs => integer().nullable()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
