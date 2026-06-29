import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../app/theme/app_colors.dart';
import '../../data/local/app_database.dart';
import '../../shared/providers/database_provider.dart';

class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen>
    with TickerProviderStateMixin {
  final _pageCtrl = PageController();

  // Step 2 state
  final _accountNameCtrl = TextEditingController(text: 'Efectivo');
  final _balanceCtrl = TextEditingController();
  String _accountType = 'cash';
  String _colorHex = '#10B981';
  bool _saving = false;

  late AnimationController _fadeCtrl;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _accountNameCtrl.dispose();
    _balanceCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _next() {
    _pageCtrl.nextPage(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _createAccount() async {
    final name = _accountNameCtrl.text.trim();
    final balance = double.tryParse(_balanceCtrl.text.trim().replaceAll(',', '.')) ?? 0;
    if (name.isEmpty) return;

    setState(() => _saving = true);
    final db = ref.read(databaseProvider);
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.accountDao.insertAccount(AccountsCompanion(
      id: Value(const Uuid().v4()),
      name: Value(name),
      type: Value(_accountType),
      initialBalanceCents: Value((balance * 100).round()),
      currency: const Value('PEN'),
      colorHex: Value(_colorHex),
      iconKey: Value(_accountType == 'cash' ? 'wallet' : 'building_library'),
      createdAt: Value(now),
    ));

    setState(() => _saving = false);
    _next();
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('welcomed', true);
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: FadeTransition(
        opacity: _fade,
        child: PageView(
          controller: _pageCtrl,
          physics: const NeverScrollableScrollPhysics(),
          onPageChanged: (_) {},
          children: [
            _PageWelcome(onContinue: _next),
            _PageSetupAccount(
              nameCtrl: _accountNameCtrl,
              balanceCtrl: _balanceCtrl,
              accountType: _accountType,
              colorHex: _colorHex,
              saving: _saving,
              onTypeChanged: (t) => setState(() => _accountType = t),
              onColorChanged: (c) => setState(() => _colorHex = c),
              onContinue: _createAccount,
            ),
            _PageDone(onFinish: _finish),
          ],
        ),
      ),
    );
  }
}

// ── Paso 1: Bienvenida ────────────────────────────────────────────────────────

class _PageWelcome extends StatelessWidget {
  final VoidCallback onContinue;
  const _PageWelcome({required this.onContinue});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Spacer(flex: 3),
            Container(
              width: 40, height: 3,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Shannon',
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    fontSize: 48,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1,
                  ),
            ),
            const SizedBox(height: 28),
            Text(
              'Toda reina merece un regalo\nque lleve su nombre.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 18,
                    height: 1.6,
                  ),
            ),
            const SizedBox(height: 20),
            Text(
              'Esta app es tuya.\nCreada para ti, solo para ti.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 18,
                    height: 1.6,
                  ),
            ),
            const SizedBox(height: 40),
            Text(
              '— Lionel',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.primaryLight,
                    fontStyle: FontStyle.italic,
                    fontSize: 17,
                  ),
            ),
            const Spacer(flex: 3),
            _ContinueButton(label: 'Continuar', icon: Icons.arrow_forward, onTap: onContinue),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ── Paso 2: Primera cuenta ────────────────────────────────────────────────────

const _accountTypes = [
  ('cash',    'Efectivo',  Icons.payments_outlined,         '#10B981'),
  ('bank',    'Banco',     Icons.account_balance_outlined,  '#6366F1'),
  ('wallet',  'Billetera', Icons.account_balance_wallet_outlined, '#F59E0B'),
];

class _PageSetupAccount extends StatelessWidget {
  final TextEditingController nameCtrl;
  final TextEditingController balanceCtrl;
  final String accountType;
  final String colorHex;
  final bool saving;
  final ValueChanged<String> onTypeChanged;
  final ValueChanged<String> onColorChanged;
  final VoidCallback onContinue;

  const _PageSetupAccount({
    required this.nameCtrl,
    required this.balanceCtrl,
    required this.accountType,
    required this.colorHex,
    required this.saving,
    required this.onTypeChanged,
    required this.onColorChanged,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 28, right: 28, top: 40,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('¿Cuánto tienes\nahora mismo?',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      )),
              const SizedBox(height: 10),
              Text(
                'Crea tu primera cuenta para empezar a\nseguir tus finanzas.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
              ),
              const SizedBox(height: 32),

              // Tipo de cuenta
              Text('Tipo', style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: AppColors.textMuted)),
              const SizedBox(height: 10),
              Row(
                children: _accountTypes.map((t) {
                  final sel = accountType == t.$1;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () {
                          onTypeChanged(t.$1);
                          onColorChanged(t.$4);
                          final defaultName = t.$2;
                          if (['Efectivo', 'Banco', 'Billetera']
                              .contains(nameCtrl.text.trim())) {
                            nameCtrl.text = defaultName;
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: sel
                                ? AppColors.primary.withValues(alpha: 0.15)
                                : AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: sel ? AppColors.primary : AppColors.border),
                          ),
                          child: Column(
                            children: [
                              Icon(t.$3,
                                  color: sel ? AppColors.primary : AppColors.textMuted,
                                  size: 22),
                              const SizedBox(height: 4),
                              Text(t.$2,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: sel ? AppColors.primary : AppColors.textMuted,
                                    fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                                  )),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // Nombre
              TextField(
                controller: nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nombre de la cuenta'),
              ),
              const SizedBox(height: 16),

              // Saldo
              TextField(
                controller: balanceCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: false,
                style: const TextStyle(
                    fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Saldo actual',
                  hintText: '0.00',
                  prefixText: 'S/ ',
                  prefixStyle: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.income),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Puedes ajustar esto después en Más → Cuentas',
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: AppColors.textMuted),
              ),
              const SizedBox(height: 36),

              _ContinueButton(
                label: saving ? 'Guardando…' : 'Crear cuenta',
                icon: Icons.check,
                onTap: saving ? () {} : onContinue,
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('welcomed', true);
                    if (context.mounted) context.go('/');
                  },
                  child: Text('Ahora no, ir a la app',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Paso 3: Listo ─────────────────────────────────────────────────────────────

class _PageDone extends StatelessWidget {
  final VoidCallback onFinish;
  const _PageDone({required this.onFinish});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Spacer(flex: 2),
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: AppColors.income.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.check_rounded,
                  color: AppColors.income, size: 36),
            ),
            const SizedBox(height: 32),
            Text(
              '¡Todo listo,\nShannon!',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
            ),
            const SizedBox(height: 20),
            _FeatureRow(icon: Icons.receipt_long_outlined, text: 'Registra gastos e ingresos'),
            const SizedBox(height: 12),
            _FeatureRow(icon: Icons.camera_alt_outlined, text: 'Escanea bauchers con la cámara'),
            const SizedBox(height: 12),
            _FeatureRow(icon: Icons.event_repeat_outlined, text: 'Programa pagos recurrentes'),
            const SizedBox(height: 12),
            _FeatureRow(icon: Icons.savings_outlined, text: 'Crea metas de ahorro'),
            const SizedBox(height: 12),
            _FeatureRow(icon: Icons.backup_outlined, text: 'Haz backup de tus datos'),
            const Spacer(flex: 2),
            _ContinueButton(
              label: 'Empezar',
              icon: Icons.arrow_forward,
              onTap: onFinish,
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _FeatureRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primaryLight, size: 18),
        ),
        const SizedBox(width: 14),
        Text(text, style: Theme.of(context).textTheme.bodyLarge
            ?.copyWith(color: AppColors.textSecondary)),
      ],
    );
  }
}

// ── Shared button ─────────────────────────────────────────────────────────────

class _ContinueButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _ContinueButton({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            Icon(icon, size: 18),
          ],
        ),
      ),
    );
  }
}
