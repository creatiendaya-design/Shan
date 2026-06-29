import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/local/app_database.dart';
import '../../data/local/seed/default_categories.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final dbInitProvider = FutureProvider<void>((ref) async {
  final db = ref.watch(databaseProvider);
  await seedDefaultCategories(db);
});
