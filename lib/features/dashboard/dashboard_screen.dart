import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../app/theme/app_colors.dart';
import '../../data/local/app_database.dart';
import '../../shared/providers/transaction_providers.dart';
import '../../shared/providers/database_provider.dart';
import '../streak/streak_service.dart';
import '../quick/quick_transactions_row.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final summary    = ref.watch(monthlySummaryProvider((now.year, now.month)));
    final txAsync    = ref.watch(transactionsByMonthProvider((now.year, now.month)));
    final spending   = ref.watch(spendingByCategoryProvider((now.year, now.month))).valueOrNull ?? {};
    final categories = ref.watch(categoriesProvider).valueOrNull ?? [];
    final totalBal   = ref.watch(totalBalanceProvider).valueOrNull;
    final upcoming   = ref.watch(upcomingPaymentsProvider).valueOrNull ?? [];
    final budgets    = ref.watch(_budgetsThisMonthProvider(now)).valueOrNull ?? [];

    final income  = summary.valueOrNull?.$1 ?? 0;
    final expense = summary.valueOrNull?.$2 ?? 0;
    final streak  = ref.watch(streakProvider).valueOrNull;
    final incomeGoal   = ref.watch(incomeGoalProvider).valueOrNull ?? 0;

    // Mes anterior
    final prevMonth = now.month == 1
        ? DateTime(now.year - 1, 12)
        : DateTime(now.year, now.month - 1);
    final prevSummary = ref.watch(monthlySummaryProvider((prevMonth.year, prevMonth.month)));
    final prevExpense = prevSummary.valueOrNull?.$2 ?? 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.surface,
          onRefresh: () async {
            ref.invalidate(monthlySummaryProvider);
            ref.invalidate(spendingByCategoryProvider);
            ref.invalidate(totalBalanceProvider);
            ref.invalidate(upcomingPaymentsProvider);
            ref.invalidate(streakProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Header(now: now, streak: streak),
                const SizedBox(height: 14),

                // ── Accesos rápidos ───────────────────────────────────────
                const QuickTransactionsRow(),
                const SizedBox(height: 16),

                // ── Saldo total real ──────────────────────────────────────
                _TotalBalanceCard(totalCents: totalBal),
                const SizedBox(height: 12),

                // ── Ingresos / Gastos del mes ─────────────────────────────
                Row(children: [
                  Expanded(child: _SummaryCard(label: 'Ingresos', cents: income,
                      icon: Icons.arrow_downward, color: AppColors.income)),
                  const SizedBox(width: 12),
                  Expanded(child: _SummaryCard(label: 'Gastos', cents: expense,
                      icon: Icons.arrow_upward, color: AppColors.expense)),
                ]),
                const SizedBox(height: 8),

                // ── Comparativa mes anterior ──────────────────────────────
                if (prevExpense > 0)
                  _MonthComparison(current: expense, previous: prevExpense, prevMonth: prevMonth),

                // ── Meta de ingreso ───────────────────────────────────────
                const SizedBox(height: 12),
                _IncomeGoalCard(goalCents: incomeGoal, incomeCents: income, ref: ref),

                // ── Próximos vencimientos ─────────────────────────────────
                if (upcoming.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text('Próximos 7 días', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 10),
                  _UpcomingList(items: upcoming),
                ],

                // ── Presupuestos del mes ──────────────────────────────────
                if (budgets.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text('Presupuestos', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 10),
                  _BudgetsMini(budgets: budgets, spending: spending, categories: categories),
                ],

                // ── Gastos por categoría ──────────────────────────────────
                if (spending.values.any((v) => v > 0)) ...[
                  const SizedBox(height: 24),
                  Text('Gastos por categoría', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  _SpendingChart(spending: spending, categories: categories),
                ],

                // ── Movimientos recientes ─────────────────────────────────
                const SizedBox(height: 24),
                Text('Movimientos recientes', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                txAsync.when(
                  data: (txs) => txs.isEmpty
                      ? _EmptyTransactions()
                      : _RecentList(txs: txs, categories: categories),
                  loading: () => const Center(
                    child: Padding(padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(color: AppColors.primary))),
                  error: (e, s) => const SizedBox(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Provider local para presupuestos del mes actual
final _budgetsThisMonthProvider =
    FutureProvider.autoDispose.family<List<Budget>, DateTime>((ref, now) {
  final db = ref.watch(databaseProvider);
  return db.budgetDao.getByMonth(now.year, now.month);
});

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final DateTime now;
  final StreakData? streak;
  const _Header({required this.now, this.streak});

  @override
  Widget build(BuildContext context) {
    final monthName = DateFormat('MMMM yyyy', 'es').format(now);
    final current = streak?.current ?? 0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Hola, Shannon', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 4),
          Row(children: [
            Text(monthName, style: Theme.of(context).textTheme.bodyMedium),
            if (current > 0) ...[
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Text('🔥', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 3),
                  Text(
                    '$current ${current == 1 ? 'día' : 'días'}',
                    style: const TextStyle(
                        fontSize: 11, color: Colors.orange, fontWeight: FontWeight.w600),
                  ),
                ]),
              ),
            ],
          ]),
        ]),
        CircleAvatar(
          radius: 22,
          backgroundColor: AppColors.primary,
          child: const Text('S',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

// ── Saldo total real ──────────────────────────────────────────────────────────

class _TotalBalanceCard extends StatelessWidget {
  final int? totalCents;
  const _TotalBalanceCard({this.totalCents});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: 'S/ ', decimalDigits: 2);
    final amount = totalCents != null ? totalCents! / 100 : null;
    final isPositive = (amount ?? 0) >= 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Saldo total',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.white70)),
        const SizedBox(height: 8),
        amount == null
            ? const SizedBox(height: 44,
                child: Center(child: CircularProgressIndicator(color: Colors.white54, strokeWidth: 2)))
            : Text(fmt.format(amount),
                style: Theme.of(context).textTheme.displayLarge
                    ?.copyWith(color: Colors.white, fontSize: 40)),
        const SizedBox(height: 8),
        Row(children: [
          Icon(isPositive ? Icons.account_balance_wallet_outlined : Icons.warning_amber_outlined,
              color: Colors.white70, size: 14),
          const SizedBox(width: 4),
          Text('Todas las cuentas combinadas',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white70)),
        ]),
      ]),
    );
  }
}

// ── Próximos vencimientos ─────────────────────────────────────────────────────

class _UpcomingList extends StatelessWidget {
  final List<UpcomingPayment> items;
  const _UpcomingList({required this.items});

  String _dateLabel(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(d.year, d.month, d.day);
    final diff = target.difference(today).inDays;
    if (diff < 0) return 'Vencida';
    if (diff == 0) return 'Hoy';
    if (diff == 1) return 'Mañana';
    return 'En $diff días';
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: 'S/ ', decimalDigits: 2);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: items.asMap().entries.map((e) {
          final i = e.key;
          final item = e.value;
          final isOverdue = item.isOverdue;
          final color = isOverdue
              ? AppColors.expense
              : item.isExpense
                  ? AppColors.expense
                  : AppColors.income;
          final icon = item.kind == 'debt'
              ? Icons.handshake_outlined
              : Icons.event_repeat_outlined;

          return Column(children: [
            ListTile(
              leading: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              title: Text(item.name, style: Theme.of(context).textTheme.bodyLarge),
              subtitle: Text(
                _dateLabel(item.dueDate),
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: isOverdue ? AppColors.expense : AppColors.textMuted),
              ),
              trailing: Text(
                fmt.format(item.amountCents / 100),
                style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ),
            if (i < items.length - 1)
              const Divider(height: 1, indent: 56, color: AppColors.border),
          ]);
        }).toList(),
      ),
    );
  }
}

// ── Presupuestos mini ─────────────────────────────────────────────────────────

class _BudgetsMini extends StatelessWidget {
  final List<Budget> budgets;
  final Map<String, int> spending;
  final List<Category> categories;
  const _BudgetsMini({required this.budgets, required this.spending, required this.categories});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: 'S/ ', decimalDigits: 0);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: budgets.map((b) {
          final spent = b.categoryId != null ? (spending[b.categoryId] ?? 0) : 0;
          final ratio = b.limitCents > 0 ? (spent / b.limitCents).clamp(0.0, 1.0) : 0.0;
          final over  = spent > b.limitCents;
          final color = over ? AppColors.expense : ratio > 0.8 ? Colors.orange : AppColors.income;
          final cat   = categories.where((c) => c.id == b.categoryId).firstOrNull;

          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(cat?.name ?? 'General',
                    style: Theme.of(context).textTheme.bodyMedium),
                Text('${fmt.format(spent / 100)} / ${fmt.format(b.limitCents / 100)}',
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: over ? AppColors.expense : AppColors.textMuted)),
              ]),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: ratio,
                  backgroundColor: AppColors.surfaceVariant,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  minHeight: 6,
                ),
              ),
            ]),
          );
        }).toList(),
      ),
    );
  }
}

// ── Movimientos recientes ─────────────────────────────────────────────────────

class _RecentList extends StatelessWidget {
  final List<Transaction> txs;
  final List<Category> categories;
  const _RecentList({required this.txs, required this.categories});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: 'S/ ', decimalDigits: 2);
    final recent = txs.take(8).toList();
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: recent.asMap().entries.map((e) {
          final i = e.key;
          final tx = e.value;
          final isIncome   = tx.type == 'income';
          final isTransfer = tx.type == 'transfer';
          final color = isTransfer ? AppColors.primaryLight
              : isIncome ? AppColors.income : AppColors.expense;
          final sign  = isIncome ? '+' : isTransfer ? '↔' : '-';
          final date  = DateTime.fromMillisecondsSinceEpoch(tx.date);
          final cat   = categories.where((c) => c.id == tx.categoryId).firstOrNull;

          return Column(children: [
            ListTile(
              leading: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(
                  isIncome ? Icons.arrow_downward
                      : isTransfer ? Icons.swap_horiz : Icons.arrow_upward,
                  color: color, size: 18),
              ),
              title: Text(cat?.name ?? (isTransfer ? 'Transferencia' : 'Sin categoría'),
                  style: Theme.of(context).textTheme.bodyLarge),
              subtitle: Text(
                '${date.day}/${date.month}${tx.note != null ? ' · ${tx.note}' : ''}',
                style: Theme.of(context).textTheme.labelSmall),
              trailing: Text('$sign${fmt.format(tx.amountCents / 100)}',
                  style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 15)),
            ),
            if (i < recent.length - 1)
              const Divider(height: 1, indent: 56, color: AppColors.border),
          ]);
        }).toList(),
      ),
    );
  }
}

class _EmptyTransactions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: [
        const Icon(Icons.receipt_long_outlined, size: 48, color: AppColors.textMuted),
        const SizedBox(height: 12),
        Text('Sin movimientos',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.textMuted)),
        const SizedBox(height: 4),
        Text('Toca + para agregar tu primer gasto',
            style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
      ]),
    );
  }
}

// ── Comparativa mes anterior ──────────────────────────────────────────────────

class _MonthComparison extends StatelessWidget {
  final int current;
  final int previous;
  final DateTime prevMonth;
  const _MonthComparison(
      {required this.current, required this.previous, required this.prevMonth});

  @override
  Widget build(BuildContext context) {
    final diff = current - previous;
    final better = diff < 0;
    final fmt = NumberFormat.currency(symbol: 'S/ ', decimalDigits: 0);
    final monthName = DateFormat('MMMM', 'es').format(prevMonth);
    final label = better
        ? 'Gastaste ${fmt.format(diff.abs() / 100)} menos que en $monthName ↓'
        : diff == 0
            ? 'Mismo gasto que en $monthName'
            : 'Gastaste ${fmt.format(diff / 100)} más que en $monthName ↑';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: better
            ? AppColors.income.withValues(alpha: 0.08)
            : AppColors.expense.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: better
              ? AppColors.income.withValues(alpha: 0.25)
              : AppColors.expense.withValues(alpha: 0.25),
        ),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: better ? AppColors.income : AppColors.expense,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

// ── Meta de ingreso mensual ───────────────────────────────────────────────────

class _IncomeGoalCard extends StatelessWidget {
  final int goalCents;
  final int incomeCents;
  final WidgetRef ref;
  const _IncomeGoalCard(
      {required this.goalCents, required this.incomeCents, required this.ref});

  Future<void> _editGoal(BuildContext context) async {
    final ctrl = TextEditingController(
      text: goalCents > 0 ? (goalCents / 100).toStringAsFixed(0) : '',
    );
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Meta de ingresos del mes'),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: const InputDecoration(
            prefixText: 'S/ ',
            hintText: '3000',
            labelText: '¿Cuánto quieres ganar este mes?',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              final v = double.tryParse(ctrl.text.trim().replaceAll(',', '.'));
              Navigator.pop(ctx, v != null ? (v * 100).round() : null);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (result != null) {
      await ref.read(incomeGoalProvider.notifier).setGoal(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: 'S/ ', decimalDigits: 0);
    final ratio = goalCents > 0
        ? (incomeCents / goalCents).clamp(0.0, 1.0)
        : 0.0;
    final pct = (ratio * 100).round();
    final reached = incomeCents >= goalCents && goalCents > 0;

    return GestureDetector(
      onTap: () => _editGoal(context),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: reached
                ? AppColors.income.withValues(alpha: 0.5)
                : AppColors.border,
          ),
        ),
        child: goalCents == 0
            ? Row(children: [
                const Icon(Icons.add_circle_outline,
                    color: AppColors.textMuted, size: 20),
                const SizedBox(width: 10),
                Text('Fijar meta de ingresos del mes',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppColors.textMuted)),
              ])
            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Meta de ingresos',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(color: AppColors.textMuted)),
                      Row(children: [
                        if (reached)
                          const Text('🎉 ', style: TextStyle(fontSize: 14)),
                        Text(
                          '${fmt.format(incomeCents / 100)} / ${fmt.format(goalCents / 100)}',
                          style: Theme.of(context)
                              .textTheme
                              .labelMedium
                              ?.copyWith(
                                color: reached
                                    ? AppColors.income
                                    : AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ]),
                    ]),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 7,
                    backgroundColor: AppColors.surfaceVariant,
                    valueColor: AlwaysStoppedAnimation<Color>(
                        reached ? AppColors.income : AppColors.primary),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  reached
                      ? '¡Meta alcanzada! 🌟'
                      : '$pct% — te faltan ${fmt.format((goalCents - incomeCents) / 100)}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: reached ? AppColors.income : AppColors.textMuted,
                      ),
                ),
              ]),
      ),
    );
  }
}

// ── Gráfica de dona ──────────────────────────────────────────────────────────

const _chartColors = [
  Color(0xFF881337),
  Color(0xFFBE185D),
  Color(0xFFE11D48),
  Color(0xFF9F1239),
  Color(0xFFDB2777),
  Color(0xFFF43F5E),
  Color(0xFFFB7185),
  Color(0xFFFFB3C6),
  Color(0xFF6D1A36),
  Color(0xFFC4455D),
];

class _SpendingChart extends StatefulWidget {
  final Map<String, int> spending;
  final List<Category> categories;

  const _SpendingChart({required this.spending, required this.categories});

  @override
  State<_SpendingChart> createState() => _SpendingChartState();
}

class _SpendingChartState extends State<_SpendingChart> {
  int? _touchedIndex;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: 'S/ ', decimalDigits: 0);
    final entries = widget.spending.entries
        .where((e) => e.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final total = entries.fold<int>(0, (s, e) => s + e.value);

    final sections = entries.asMap().entries.map((e) {
      final idx = e.key;
      final entry = e.value;
      final isTouched = _touchedIndex == idx;
      final pct = entry.value / total;
      return PieChartSectionData(
        value: entry.value.toDouble(),
        color: _chartColors[idx % _chartColors.length],
        radius: isTouched ? 56.0 : 48.0,
        title: pct > 0.08 ? '${(pct * 100).toStringAsFixed(0)}%' : '',
        titleStyle: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      );
    }).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 180,
            child: PieChart(
              PieChartData(
                sections: sections,
                centerSpaceRadius: 50,
                sectionsSpace: 2,
                pieTouchData: PieTouchData(
                  touchCallback: (event, response) {
                    if (!mounted) return;
                    setState(() {
                      if (!event.isInterestedForInteractions ||
                          response == null ||
                          response.touchedSection == null) {
                        _touchedIndex = null;
                      } else {
                        _touchedIndex =
                            response.touchedSection!.touchedSectionIndex;
                      }
                    });
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 12),
          ...entries.asMap().entries.map((e) {
            final idx = e.key;
            final entry = e.value;
            final cat = widget.categories
                .where((c) => c.id == entry.key)
                .firstOrNull;
            final color = _chartColors[idx % _chartColors.length];
            final pct = (entry.value / total * 100).toStringAsFixed(1);

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                        color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(cat?.name ?? 'Sin categoría',
                        style: Theme.of(context).textTheme.bodyMedium),
                  ),
                  Text('$pct%',
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: AppColors.textMuted)),
                  const SizedBox(width: 10),
                  Text(fmt.format(entry.value / 100),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.expense,
                          )),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final int cents;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.label,
    required this.cents,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: 'S/ ', decimalDigits: 2);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 10),
          Text(
            fmt.format(cents / 100),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
          ),
          const SizedBox(height: 2),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

