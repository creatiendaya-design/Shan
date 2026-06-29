import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../app/theme/app_colors.dart';

class BackupService {
  static Future<File> _dbFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, 'shannon.db'));
  }

  // ── Export ────────────────────────────────────────────────────────────────

  static Future<void> backup(BuildContext context) async {
    try {
      final src = await _dbFile();
      if (!await src.exists()) {
        if (context.mounted) _snack(context, 'No se encontró la base de datos');
        return;
      }

      final tmp = await getTemporaryDirectory();
      final now = DateTime.now();
      final stamp =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      final dest = File(p.join(tmp.path, 'shannon_backup_$stamp.db'));
      await src.copy(dest.path);

      if (!context.mounted) return;
      await SharePlus.instance.share(ShareParams(
        files: [XFile(dest.path)],
        subject: 'Shannon — Backup $stamp',
      ));
    } catch (e) {
      if (context.mounted) {
        _snack(context, 'Error al crear backup: $e');
      }
    }
  }

  // ── Restore ───────────────────────────────────────────────────────────────

  static Future<void> restore(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Restaurar backup'),
        content: const Text(
          'Esto reemplazará TODOS tus datos actuales con los del backup.\n\n'
          'Después de restaurar deberás cerrar y volver a abrir la app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar',
                style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.expense),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return;
      final picked = result.files.first;
      if (picked.path == null) {
        if (context.mounted) _snack(context, 'No se pudo acceder al archivo');
        return;
      }

      final srcFile = File(picked.path!);
      final destFile = await _dbFile();
      await srcFile.copy(destFile.path);

      if (context.mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            backgroundColor: AppColors.surface,
            title: const Text('Restauración completada'),
            content: const Text(
              'Los datos fueron restaurados. Cierra y vuelve a abrir la app para ver los cambios.',
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
                child: const Text('Entendido'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        _snack(context, 'Error al restaurar: $e');
      }
    }
  }

  static void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.surface),
    );
  }
}

