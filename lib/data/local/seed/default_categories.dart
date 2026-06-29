import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../app_database.dart';

const _uuid = Uuid();

Future<void> seedDefaultCategories(AppDatabase db) async {
  final exists = await db.categoryDao.exists();
  if (exists) return;

  final expenses = [
    ('Comida', 'utensils', '#EF4444'),
    ('Transporte', 'car', '#F59E0B'),
    ('Salud', 'heart-pulse', '#10B981'),
    ('Entretenimiento', 'music', '#8B5CF6'),
    ('Ropa', 'shopping-bag', '#EC4899'),
    ('Hogar', 'home', '#3B82F6'),
    ('Educación', 'book-open', '#06B6D4'),
    ('Tecnología', 'smartphone', '#6366F1'),
    ('Mascotas', 'paw-print', '#F97316'),
    ('Otros', 'more-horizontal', '#64748B'),
  ];

  final incomes = [
    ('Salario', 'briefcase', '#10B981'),
    ('Freelance', 'laptop', '#3B82F6'),
    ('Inversiones', 'trending-up', '#8B5CF6'),
    ('Regalo', 'gift', '#EC4899'),
    ('Otros ingresos', 'plus-circle', '#64748B'),
  ];

  int order = 0;
  for (final e in expenses) {
    await db.categoryDao.insertCategory(CategoriesCompanion(
      id: Value(_uuid.v4()),
      name: Value(e.$1),
      kind: const Value('expense'),
      iconKey: Value(e.$2),
      colorHex: Value(e.$3),
      isDefault: const Value(true),
      sortOrder: Value(order++),
    ));
  }

  for (final i in incomes) {
    await db.categoryDao.insertCategory(CategoriesCompanion(
      id: Value(_uuid.v4()),
      name: Value(i.$1),
      kind: const Value('income'),
      iconKey: Value(i.$2),
      colorHex: Value(i.$3),
      isDefault: const Value(true),
      sortOrder: Value(order++),
    ));
  }
}
