import 'package:drift/drift.dart';

class Investments extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get type => text()(); // stocks | crypto | real_estate | savings | other
  IntColumn get initialAmountCents => integer()();
  IntColumn get currentValueCents => integer()();
  TextColumn get currency => text().withDefault(const Constant('PEN'))();
  TextColumn get note => text().nullable()();
  IntColumn get startDateMs => integer()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
