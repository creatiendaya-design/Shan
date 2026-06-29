import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/local/app_database.dart';
import 'database_provider.dart';

final budgetsByMonthProvider =
    StreamProvider.autoDispose.family<List<Budget>, (int, int)>((ref, args) {
  final (year, month) = args;
  final db = ref.watch(databaseProvider);
  return db.budgetDao.watchByMonth(year, month);
});
