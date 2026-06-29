import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../app/theme/app_colors.dart';
import '../../data/local/app_database.dart';
import '../../shared/providers/database_provider.dart';

final _investmentsProvider = StreamProvider.autoDispose<List<Investment>>((ref) {
  return ref.watch(databaseProvider).investmentDao.watchAll();
});

const _investmentTypes = [
  ('stocks', 'Acciones', Icons.show_chart),
  ('crypto', 'Cripto', Icons.currency_bitcoin),
  ('real_estate', 'Inmueble', Icons.home_outlined),
  ('savings', 'Ahorro fijo', Icons.savings_outlined),
  ('other', 'Otro', Icons.category_outlined),
];

class InvestmentsScreen extends ConsumerWidget {
  const InvestmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invAsync = ref.watch(_investmentsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Inversiones', style: Theme.of(context).textTheme.headlineMedium),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () => _showForm(context, null),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: invAsync.when(
        data: (investments) {
          if (investments.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.trending_up_outlined, size: 64, color: AppColors.textMuted),
                  const SizedBox(height: 16),
                  Text('Sin inversiones registradas',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.textMuted)),
                  const SizedBox(height: 8),
                  Text('Toca + para agregar una inversión',
                      style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            );
          }

          final totalInitial = investments.fold<int>(0, (s, i) => s + i.initialAmountCents);
          final totalCurrent = investments.fold<int>(0, (s, i) => s + i.currentValueCents);
          final gain = totalCurrent - totalInitial;
          final gainPct = totalInitial > 0 ? (gain / totalInitial * 100) : 0.0;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
            children: [
              _PortfolioCard(
                totalCurrent: totalCurrent,
                gain: gain,
                gainPct: gainPct,
              ),
              const SizedBox(height: 20),
              Text('Mi portafolio',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppColors.textMuted)),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: investments.asMap().entries.map((e) {
                    final i = e.key;
                    final inv = e.value;
                    return Column(
                      children: [
                        _InvestmentTile(
                          investment: inv,
                          onTap: () => _showForm(context, inv),
                        ),
                        if (i < investments.length - 1)
                          const Divider(height: 1, indent: 56, color: AppColors.border),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, st) => const SizedBox(),
      ),
    );
  }

  void _showForm(BuildContext context, Investment? inv) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _InvestmentFormSheet(investment: inv),
    );
  }
}

class _PortfolioCard extends StatelessWidget {
  final int totalCurrent;
  final int gain;
  final double gainPct;
  const _PortfolioCard({required this.totalCurrent, required this.gain, required this.gainPct});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: 'S/ ', decimalDigits: 2);
    final isPositive = gain >= 0;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Valor total del portafolio',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Colors.white70)),
          const SizedBox(height: 8),
          Text(fmt.format(totalCurrent / 100),
              style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(isPositive ? Icons.trending_up : Icons.trending_down,
                  color: isPositive ? AppColors.income : Colors.white54, size: 16),
              const SizedBox(width: 4),
              Text(
                '${isPositive ? '+' : ''}${fmt.format(gain / 100)} (${gainPct.toStringAsFixed(1)}%)',
                style: TextStyle(
                  color: isPositive ? AppColors.income : Colors.white60,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InvestmentTile extends StatelessWidget {
  final Investment investment;
  final VoidCallback onTap;
  const _InvestmentTile({required this.investment, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: 'S/ ', decimalDigits: 2);
    final gain = investment.currentValueCents - investment.initialAmountCents;
    final isPositive = gain >= 0;
    final typeInfo = _investmentTypes.firstWhere(
      (t) => t.$1 == investment.type,
      orElse: () => _investmentTypes.last,
    );

    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(typeInfo.$3, color: AppColors.primary, size: 20),
      ),
      title: Text(investment.name, style: Theme.of(context).textTheme.bodyLarge),
      subtitle: Text(typeInfo.$2, style: Theme.of(context).textTheme.labelSmall),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(fmt.format(investment.currentValueCents / 100),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
          Text(
            '${isPositive ? '+' : ''}${fmt.format(gain / 100)}',
            style: TextStyle(
              color: isPositive ? AppColors.income : AppColors.expense,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Formulario ────────────────────────────────────────────────────────────────

class _InvestmentFormSheet extends ConsumerStatefulWidget {
  final Investment? investment;
  const _InvestmentFormSheet({this.investment});

  @override
  ConsumerState<_InvestmentFormSheet> createState() => _InvestmentFormSheetState();
}

class _InvestmentFormSheetState extends ConsumerState<_InvestmentFormSheet> {
  late TextEditingController _nameCtrl;
  late TextEditingController _initialCtrl;
  late TextEditingController _currentCtrl;
  late TextEditingController _noteCtrl;
  late String _type;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.investment?.name ?? '');
    _initialCtrl = TextEditingController(
        text: widget.investment != null ? (widget.investment!.initialAmountCents / 100).toStringAsFixed(2) : '');
    _currentCtrl = TextEditingController(
        text: widget.investment != null ? (widget.investment!.currentValueCents / 100).toStringAsFixed(2) : '');
    _noteCtrl = TextEditingController(text: widget.investment?.note ?? '');
    _type = widget.investment?.type ?? 'stocks';
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _initialCtrl.dispose(); _currentCtrl.dispose(); _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final initial = double.tryParse(_initialCtrl.text.trim().replaceAll(',', '.'));
    final current = double.tryParse(_currentCtrl.text.trim().replaceAll(',', '.'));
    if (name.isEmpty || initial == null || current == null) return;

    setState(() => _saving = true);
    final db = ref.read(databaseProvider);
    final now = DateTime.now().millisecondsSinceEpoch;
    final companion = InvestmentsCompanion(
      id: Value(widget.investment?.id ?? const Uuid().v4()),
      name: Value(name),
      type: Value(_type),
      initialAmountCents: Value((initial * 100).round()),
      currentValueCents: Value((current * 100).round()),
      note: Value(_noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim()),
      startDateMs: Value(widget.investment?.startDateMs ?? now),
      createdAt: Value(widget.investment?.createdAt ?? now),
    );

    if (widget.investment == null) {
      await db.investmentDao.insertInvestment(companion);
    } else {
      await db.investmentDao.updateInvestment(companion);
    }
    if (mounted) Navigator.of(context, rootNavigator: true).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(widget.investment == null ? 'Nueva inversión' : 'Editar inversión',
                    style: Theme.of(context).textTheme.titleLarge),
                if (widget.investment != null)
                  TextButton(
                    onPressed: () async {
                      final db = ref.read(databaseProvider);
                      final id = widget.investment!.id;
                      final nav = Navigator.of(context);
                      await db.investmentDao.deleteInvestment(id);
                      if (!mounted) return;
                      nav.pop();
                    },
                    child: const Text('Eliminar', style: TextStyle(color: AppColors.expense)),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: _investmentTypes.map((t) {
                final sel = _type == t.$1;
                return GestureDetector(
                  onTap: () => setState(() => _type = t.$1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: sel ? AppColors.primary.withValues(alpha: 0.15) : AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: sel ? AppColors.primary : AppColors.border),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(t.$3, size: 14, color: sel ? AppColors.primary : AppColors.textMuted),
                      const SizedBox(width: 6),
                      Text(t.$2, style: TextStyle(
                          color: sel ? AppColors.primary : AppColors.textSecondary,
                          fontSize: 13, fontWeight: sel ? FontWeight.w600 : FontWeight.w400)),
                    ]),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextField(controller: _nameCtrl,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Nombre de la inversión')),
            const SizedBox(height: 12),
            TextField(controller: _initialCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Monto invertido', prefixText: 'S/ ')),
            const SizedBox(height: 12),
            TextField(controller: _currentCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Valor actual', prefixText: 'S/ ')),
            const SizedBox(height: 12),
            TextField(controller: _noteCtrl,
                decoration: const InputDecoration(hintText: 'Nota (opcional)',
                    prefixIcon: Icon(Icons.notes_outlined, color: AppColors.textMuted))),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: Text(widget.investment == null ? 'Guardar' : 'Actualizar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

