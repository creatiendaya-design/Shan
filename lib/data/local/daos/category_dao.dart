import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/categories_table.dart';

part 'category_dao.g.dart';

@DriftAccessor(tables: [Categories])
class CategoryDao extends DatabaseAccessor<AppDatabase>
    with _$CategoryDaoMixin {
  CategoryDao(super.db);

  Stream<List<Category>> watchAll() =>
      (select(categories)..orderBy([(c) => OrderingTerm(expression: c.sortOrder)])).watch();

  Future<List<Category>> getAll() =>
      (select(categories)..orderBy([(c) => OrderingTerm(expression: c.sortOrder)])).get();

  Future<List<Category>> getByKind(String kind) =>
      (select(categories)..where((c) => c.kind.equals(kind))).get();

  Future<void> insertCategory(CategoriesCompanion entry) =>
      into(categories).insert(entry);

  Future<void> updateCategory(CategoriesCompanion entry) =>
      (update(categories)..where((c) => c.id.equals(entry.id.value)))
          .write(entry);

  Future<void> deleteCategory(String id) =>
      (delete(categories)..where((c) => c.id.equals(id))).go();

  Future<bool> exists() async {
    final count = await (selectOnly(categories)..addColumns([categories.id]))
        .get();
    return count.isNotEmpty;
  }
}
