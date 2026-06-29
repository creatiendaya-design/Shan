import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../shared/providers/database_provider.dart';
import '../../shared/providers/transaction_providers.dart';

class ExportService {
  static Future<void> exportCSV(BuildContext context, WidgetRef ref) async {
    final db = ref.read(databaseProvider);
    final categories = ref.read(categoriesProvider).valueOrNull ?? [];
    final accounts = await db.accountDao.getAll();

    final catMap = {for (final c in categories) c.id: c.name};
    final accMap = {for (final a in accounts) a.id: a.name};

    final allTx = await db.transactionDao.getAll();

    final fmt = DateFormat('dd/MM/yyyy');
    final buffer = StringBuffer();
    buffer.writeln('Fecha,Tipo,Monto,Cuenta,Categoría,Nota');

    for (final tx in allTx) {
      final date = fmt.format(DateTime.fromMillisecondsSinceEpoch(tx.date));
      final type = tx.type == 'income'
          ? 'Ingreso'
          : tx.type == 'expense'
              ? 'Gasto'
              : 'Transferencia';
      final amount = (tx.amountCents / 100).toStringAsFixed(2);
      final account = _escape(accMap[tx.accountId] ?? '');
      final category = _escape(catMap[tx.categoryId] ?? '');
      final note = _escape(tx.note ?? '');
      buffer.writeln('$date,$type,$amount,$account,$category,$note');
    }

    final dir = await getTemporaryDirectory();
    final now = DateTime.now();
    final fileName =
        'shannon_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.csv';
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(utf8.encode(buffer.toString()));

    if (!context.mounted) return;

    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path, mimeType: 'text/csv')],
      subject: 'Shannon — Mis transacciones',
    ));
  }

  static String _escape(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}
