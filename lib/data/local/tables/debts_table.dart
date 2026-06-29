import 'package:drift/drift.dart';

class Debts extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()(); // quién te debe o a quién debes
  TextColumn get direction => text()(); // 'owed_to_me' | 'i_owe'
  IntColumn get amountCents => integer()();
  TextColumn get currency => text().withDefault(const Constant('PEN'))();
  TextColumn get note => text().nullable()();
  IntColumn get dueDateMs => integer().nullable()();
  BoolColumn get paid => boolean().withDefault(const Constant(false))();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
