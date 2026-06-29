import 'package:drift/drift.dart';
import 'accounts_table.dart';
import 'categories_table.dart';

class Transactions extends Table {
  TextColumn get id => text()();
  TextColumn get type => text()(); // income | expense | transfer
  IntColumn get amountCents => integer()();
  TextColumn get currency => text().withDefault(const Constant('USD'))();
  TextColumn get accountId =>
      text().references(Accounts, #id)();
  TextColumn get transferAccountId =>
      text().nullable().references(Accounts, #id)();
  TextColumn get categoryId =>
      text().nullable().references(Categories, #id)();
  IntColumn get date => integer()(); // epoch millis
  TextColumn get note => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
