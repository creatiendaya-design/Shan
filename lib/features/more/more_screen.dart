import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
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
          _buildSection(context, 'Ajustes', [
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
          const SizedBox(height: 36),
          const _SealedEnvelope(),
          const SizedBox(height: 32),
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

// ── Sobre sellado ────────────────────────────────────────────────────────────

class _SealedEnvelope extends StatefulWidget {
  const _SealedEnvelope();

  @override
  State<_SealedEnvelope> createState() => _SealedEnvelopeState();
}

class _SealedEnvelopeState extends State<_SealedEnvelope>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 1.0, end: 1.03).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _openLetter() {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 450),
      transitionBuilder: (ctx, anim, _, child) => ScaleTransition(
        scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
        child: FadeTransition(opacity: anim, child: child),
      ),
      pageBuilder: (ctx, _, __) => const _LetterDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: GestureDetector(
        onTap: _openLetter,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFF0F5), Color(0xFFFFE0EB)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFFFB3CC), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF85A1).withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('✉️', style: TextStyle(fontSize: 30)),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Para ti',
                    style: GoogleFonts.dancingScript(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFB02050),
                    ),
                  ),
                  Text(
                    'Toca para abrir  💌',
                    style: TextStyle(
                      fontSize: 11,
                      color: const Color(0xFFB02050).withValues(alpha: 0.55),
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LetterDialog extends StatelessWidget {
  const _LetterDialog();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 26),
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBF2),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFFFD6A5), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 32,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('💌', style: TextStyle(fontSize: 44)),
                const SizedBox(height: 14),
                Text(
                  'Hola, Shannon',
                  style: GoogleFonts.dancingScript(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF8B3A20),
                  ),
                ),
                const SizedBox(height: 18),
                Container(height: 1, color: const Color(0xFFFFD6A5)),
                const SizedBox(height: 20),
                Text(
                  'Sé que apenas nos estamos conociendo,\ny precisamente por eso hice esto para ti.\n\nMe gustaría tenerte más cerca...\n¿Me darías el gusto de invitarte a salir?',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.lato(
                    fontSize: 15.5,
                    height: 1.85,
                    color: const Color(0xFF5C3317),
                  ),
                ),
                const SizedBox(height: 26),
                Container(height: 1, color: const Color(0xFFFFD6A5)),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () =>
                            Navigator.of(context, rootNavigator: true).pop(),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFFFB3CC)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        child: Text(
                          'Lo pensaré',
                          style: TextStyle(
                              color: const Color(0xFFB02050).withValues(alpha: 0.7),
                              fontSize: 13),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () =>
                            Navigator.of(context, rootNavigator: true).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFB02050),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Con gusto 💚',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
