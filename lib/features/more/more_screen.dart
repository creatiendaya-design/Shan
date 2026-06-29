import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../app/theme/app_colors.dart';
import '../about/about_screen.dart';
import '../accounts/accounts_screen.dart';
import '../categories/categories_screen.dart';
import '../recurring/recurring_screen.dart';
import '../debts/debts_screen.dart';
import '../export/backup_service.dart';
import '../export/export_service.dart';
import '../export/monthly_summary_service.dart';
import '../investments/investments_screen.dart';
import '../notifications/notification_service.dart';
import '../savings/savings_goals_screen.dart';
import '../security/security_setup_screen.dart';

class MoreScreen extends ConsumerStatefulWidget {
  const MoreScreen({super.key});

  @override
  ConsumerState<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends ConsumerState<MoreScreen> {
  bool _dailyReminder = false;

  @override
  void initState() {
    super.initState();
    _loadReminderPref();
  }

  Future<void> _loadReminderPref() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _dailyReminder = prefs.getBool('daily_reminder') ?? false);
  }

  Future<void> _toggleReminder(bool value) async {
    setState(() => _dailyReminder = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('daily_reminder', value);
    await setDailyReminder(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Más', style: Theme.of(context).textTheme.headlineMedium),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildSection(context, 'Finanzas', [
            _MoreItem(
              icon: Icons.account_balance_wallet_outlined,
              label: 'Cuentas',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AccountsScreen()),
              ),
            ),
            _MoreItem(
              icon: Icons.trending_up_outlined,
              label: 'Inversiones',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const InvestmentsScreen()),
              ),
            ),
            _MoreItem(
              icon: Icons.credit_card_outlined,
              label: 'Deudas',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const DebtsScreen()),
              ),
            ),
            _MoreItem(
              icon: Icons.savings_outlined,
              label: 'Metas de ahorro',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SavingsGoalsScreen()),
              ),
            ),
            _MoreItem(
              icon: Icons.event_repeat_outlined,
              label: 'Recurrentes',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const RecurringScreen()),
              ),
            ),
          ]),
          const SizedBox(height: 20),
          _buildSection(context, 'Configuración', [
            _MoreItem(
              icon: Icons.category_outlined,
              label: 'Categorías',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CategoriesScreen()),
              ),
            ),
            _MoreItem(
              icon: Icons.lock_outline,
              label: 'Seguridad',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SecuritySetupScreen()),
              ),
            ),
            _MoreItem(
              icon: Icons.notifications_outlined,
              label: 'Recordatorio diario (9 PM)',
              trailing: Switch(
                value: _dailyReminder,
                onChanged: _toggleReminder,
                activeThumbColor: AppColors.primary,
                trackColor: WidgetStateProperty.resolveWith(
                  (s) => s.contains(WidgetState.selected)
                      ? AppColors.primary.withValues(alpha: 0.4)
                      : AppColors.surfaceVariant,
                ),
              ),
            ),
            _MoreItem(
              icon: Icons.share_outlined,
              label: 'Resumen del mes',
              onTap: () => MonthlySummaryService.share(context, ref),
            ),
            _MoreItem(
              icon: Icons.download_outlined,
              label: 'Exportar CSV',
              onTap: () => ExportService.exportCSV(context, ref),
            ),
            _MoreItem(
              icon: Icons.backup_outlined,
              label: 'Backup',
              onTap: () => BackupService.backup(context),
            ),
            _MoreItem(
              icon: Icons.restore_outlined,
              label: 'Restaurar backup',
              onTap: () => BackupService.restore(context),
            ),
            _MoreItem(
              icon: Icons.info_outline,
              label: 'Acerca de Shannon',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AboutScreen()),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, List<_MoreItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppColors.textMuted,
                letterSpacing: 0.5,
              ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: items.asMap().entries.map((entry) {
              final i = entry.key;
              final item = entry.value;
              return Column(
                children: [
                  ListTile(
                    leading: Icon(item.icon, color: AppColors.primary, size: 22),
                    title: Text(item.label, style: Theme.of(context).textTheme.bodyLarge),
                    trailing: item.trailing ??
                        (item.onTap != null
                            ? const Icon(Icons.chevron_right,
                                color: AppColors.textMuted, size: 20)
                            : null),
                    onTap: item.onTap,
                  ),
                  if (i < items.length - 1)
                    const Divider(height: 1, indent: 56, color: AppColors.border),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _MoreItem {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Widget? trailing;
  const _MoreItem({required this.icon, required this.label, this.onTap, this.trailing});
}
