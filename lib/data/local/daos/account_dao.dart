import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/accounts_table.dart';
import '../tables/transactions_table.dart';

part 'account_dao.g.dart';

@DriftAccessor(tables: [Accounts, Transactions])
class AccountDao extends DatabaseAccessor<AppDatabase>
    with _$AccountDaoMixin {
  AccountDao(super.db);

  Stream<List<Account>> watchAll() =>
      (select(accounts)..where((a) => a.archived.equals(false))).watch();

  Future<List<Account>> getAll() =>
      (select(accounts)..where((a) => a.archived.equals(false))).get();

  Future<Account?> getById(String id) =>
      (select(accounts)..where((a) => a.id.equals(id))).getSingleOrNull();

  Future<void> insertAccount(AccountsCompanion entry) =>
      into(accounts).insert(entry);

  Future<void> updateAccount(AccountsCompanion entry) =>
      (update(accounts)..where((a) => a.id.equals(entry.id.value))).write(entry);

  Future<int> getBalanceCents(String accountId) async {
    final account = await getById(accountId);
    if (account == null) return 0;

    final incomeExpr = transactions.amountCents.sum();
    final income = await (selectOnly(transactions)
          ..addColumns([incomeExpr])
          ..where(transactions.accountId.equals(accountId) &
              transactions.type.equals('income')))
        .map((r) => r.read(incomeExpr) ?? 0)
        .getSingle();

    final expenseExpr = transactions.amountCents.sum();
    final expense = await (selectOnly(transactions)
          ..addColumns([expenseExpr])
          ..where(transactions.accountId.equals(accountId) &
              transactions.type.equals('expense')))
        .map((r) => r.read(expenseExpr) ?? 0)
        .getSingle();

    final transferOutExpr = transactions.amountCents.sum();
    final transferOut = await (selectOnly(transactions)
          ..addColumns([transferOutExpr])
          ..where(transactions.accountId.equals(accountId) &
              transactions.type.equals('transfer')))
        .map((r) => r.read(transferOutExpr) ?? 0)
        .getSingle();

    final transferInExpr = transactions.amountCents.sum();
    final transferIn = await (selectOnly(transactions)
          ..addColumns([transferInExpr])
          ..where(transactions.transferAccountId.equals(accountId)))
        .map((r) => r.read(transferInExpr) ?? 0)
        .getSingle();

    return account.initialBalanceCents + income - expense - transferOut + transferIn;
  }
}
