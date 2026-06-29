import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../shared/providers/database_provider.dart';

class MonthlySummaryService {
  static Future<void> share(BuildContext context, WidgetRef ref) async {
    final db = ref.read(databaseProvider);
    final now = DateTime.now();
    final year = now.year;
    final month = now.month;

    final income  = await db.transactionDao.sumByTypeAndMonth('income', year, month);
    final expense = await db.transactionDao.sumByTypeAndMonth('expense', year, month);
    final balance = income - expense;

    final spending   = await db.transactionDao.sumByCategoryAndMonth(year, month);
    final categories = await db.categoryDao.watchAll().first;

    // Top 3 categorías de gasto
    final sorted = spending.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top3 = sorted.take(3).toList();

    final accounts = await db.accountDao.getAll();
    int totalBalance = 0;
    for (final a in accounts) {
      totalBalance += await db.accountDao.getBalanceCents(a.id);
    }

    final fmt  = NumberFormat.currency(symbol: 'S/ ', decimalDigits: 2);
    final month_ = DateFormat('MMMM yyyy', 'es').format(now);

    final sb = StringBuffer();
    sb.writeln('📊 Resumen de $month_');
    sb.writeln('─────────────────────');
    sb.writeln('💰 Saldo total:  ${fmt.format(totalBalance / 100)}');
    sb.writeln();
    sb.writeln('📥 Ingresos:     ${fmt.format(income / 100)}');
    sb.writeln('📤 Gastos:       ${fmt.format(expense / 100)}');
    sb.writeln('📈 Balance mes:  ${fmt.format(balance / 100)}');

    if (top3.isNotEmpty) {
      sb.writeln();
      sb.writeln('🏷️ Top gastos:');
      for (final e in top3) {
        final catName = categories
            .where((c) => c.id == e.key)
            .map((c) => c.name)
            .firstOrNull ?? e.key;
        sb.writeln('  • $catName: ${fmt.format(e.value / 100)}');
      }
    }

    sb.writeln();
    sb.writeln('— Registrado con Shannon 💚');

    await SharePlus.instance.share(ShareParams(text: sb.toString()));
  }
}
