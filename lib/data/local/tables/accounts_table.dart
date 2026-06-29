import 'package:drift/drift.dart';

class Accounts extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get type => text()(); // cash | bank | savings | credit | wallet
  IntColumn get initialBalanceCents => integer().withDefault(const Constant(0))();
  TextColumn get currency => text().withDefault(const Constant('USD'))();
  TextColumn get colorHex => text().withDefault(const Constant('#881337'))();
  TextColumn get iconKey => text().withDefault(const Constant('wallet'))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
