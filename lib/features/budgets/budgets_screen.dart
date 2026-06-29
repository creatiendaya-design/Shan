import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../app/theme/app_colors.dart';
import '../../data/local/app_database.dart';
import '../../shared/providers/budget_providers.dart';
import '../../shared/providers/database_provider.dart';
import '../../shared/providers/transaction_providers.dart';

final _budgetMonthProvider =
    StateProvider<DateTime>((ref) => DateTime.now());

class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(_budgetMonthProvider);
    final budgetsAsync =
        ref.watch(budgetsByMonthProvider((month.year, month.month)));
    final spendingAsync = ref.watch(
        spendingByCategoryProvider((month.year, month.month)));
    final categories =
        ref.watch(expenseCategoriesProvider).valueOrNull ?? [];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Presupuesto',
            style: Theme.of(context).textTheme.headlineMedium),
      ),
      body: Column(
        children: [
          _MonthSelector(selected: month),
          Expanded(
            child: budgetsAsync.when(
              data: (budgets) {
                final spending = spendingAsync.valueOrNull ?? {};
                return _BudgetList(
                  budgets: budgets,
                  spending: spending,
                  categories: categories,
                  month: month,
                );
              },
              loading: () => const Center(
                  child:
                      CircularProgressIndicator(color: AppColors.primary)),
              error: (e, st) => const SizedBox(),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Selector de mes ──────────────────────────────────────────────────────────

class _MonthSelector extends ConsumerWidget {
  final DateTime selected;
  const _MonthSelector({required this.selected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = DateFormat('MMMM yyyy', 'es');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppColors.background,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => ref
                .read(_budgetMonthProvider.notifier)
                .state =
                DateTime(selected.year, selected.month - 1),
            icon: const Icon(Icons.chevron_left,
                color: AppColors.textSecondary),
          ),
          Text(fmt.format(selected),
              style: Theme.of(context).textTheme.titleMedium),
          IconButton(
            onPressed: selected.year == DateTime.now().year &&
                    selected.month == DateTime.now().month
                ? null
                : () => ref
                    .read(_budgetMonthProvider.notifier)
                    .state =
                    DateTime(selected.year, selected.month + 1),
            icon: Icon(
              Icons.chevron_right,
              color: selected.year == DateTime.now().year &&
                      selected.month == DateTime.now().month
                  ? AppColors.textMuted
                  : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Lista de presupuestos ────────────────────────────────────────────────────

class _BudgetList extends ConsumerWidget {
  final List<Budget> budgets;
  final Map<String, int> spending;
  final List<Category> categories;
  final DateTime month;

  const _BudgetList({
    required this.budgets,
    required this.spending,
    required this.categories,
    required this.month,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgetMap = {for (final b in budgets) b.categoryId ?? '': b};

    // Total del mes
    final totalLimit =
        budgets.fold<int>(0, (s, b) => s + b.limitCents);
    final totalSpent =
        spending.values.fold<int>(0, (s, v) => s + v);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      children: [
        if (budgets.isNotEmpty) ...[
          _SummaryCard(
              totalLimit: totalLimit, totalSpent: totalSpent),
          const SizedBox(height: 20),
        ],
        Text('Por categoría',
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(color: AppColors.textMuted)),
        const SizedBox(height: 10),
        ...categories.map((cat) {
          final budget = budgetMap[cat.id];
          final spent = spending[cat.id] ?? 0;
          return _CategoryBudgetCard(
            category: cat,
            budget: budget,
            spentCents: spent,
            month: month,
          );
        }),
        const SizedBox(height: 8),
        Center(
          child: Text(
            '${budgets.length} de ${categories.length} categorías con límite',
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: AppColors.textMuted),
          ),
        ),
      ],
    );
  }
}

// ── Resumen total ────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final int totalLimit;
  final int totalSpent;
  const _SummaryCard(
      {required this.totalLimit, required this.totalSpent});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: 'S/ ', decimalDigits: 0);
    final remaining = totalLimit - totalSpent;
    final progress = totalLimit > 0
        ? (totalSpent / totalLimit).clamp(0.0, 1.0)
        : 0.0;
    final isOver = totalSpent > totalLimit;

    return Container(
      padding: const EdgeInsets.all(20),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Gasto total del mes',
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(color: Colors.white70)),
              Text(
                isOver ? 'Límite superado' : 'Disponible',
                style: const TextStyle(
                    color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(fmt.format(totalSpent / 100),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('/ ${fmt.format(totalLimit / 100)}',
                    style: const TextStyle(
                        color: Colors.white60, fontSize: 14)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white24,
              valueColor: AlwaysStoppedAnimation<Color>(
                  isOver ? AppColors.expense : Colors.white),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isOver
                ? 'Excediste por ${fmt.format((totalSpent - totalLimit).abs() / 100)}'
                : 'Te quedan ${fmt.format(remaining / 100)}',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ── Tarjeta por categoría ────────────────────────────────────────────────────

class _CategoryBudgetCard extends ConsumerWidget {
  final Category category;
  final Budget? budget;
  final int spentCents;
  final DateTime month;

  const _CategoryBudgetCard({
    required this.category,
    required this.budget,
    required this.spentCents,
    required this.month,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = NumberFormat.currency(symbol: 'S/ ', decimalDigits: 0);
    final hasBudget = budget != null;
    final limitCents = budget?.limitCents ?? 0;
    final progress = hasBudget && limitCents > 0
        ? (spentCents / limitCents).clamp(0.0, 1.0)
        : 0.0;
    final isOver = hasBudget && spentCents > limitCents;

    final progressColor = isOver
        ? AppColors.expense
        : progress > 0.8
            ? Colors.orange
            : AppColors.income;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOver ? AppColors.expense.withValues(alpha: 0.4) : AppColors.border,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(category.name,
                  style: Theme.of(context).textTheme.bodyLarge),
              const Spacer(),
              if (hasBudget) ...[
                Text(
                  fmt.format(spentCents / 100),
                  style: TextStyle(
                    color:
                        isOver ? AppColors.expense : AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  ' / ${fmt.format(limitCents / 100)}',
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 13),
                ),
              ] else ...[
                Text(
                  spentCents > 0 ? fmt.format(spentCents / 100) : 'Sin límite',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.textMuted),
                ),
              ],
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _showBudgetDialog(context, ref),
                child: Icon(
                  hasBudget ? Icons.edit_outlined : Icons.add_circle_outline,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
            ],
          ),
          if (hasBudget) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: AppColors.surfaceVariant,
                valueColor:
                    AlwaysStoppedAnimation<Color>(progressColor),
                minHeight: 5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showBudgetDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController(
      text: budget != null
          ? (budget!.limitCents / 100).toStringAsFixed(0)
          : '',
    );
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Límite para ${category.name}'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            prefixText: 'S/ ',
            hintText: '0',
            labelText: 'Monto mensual',
          ),
        ),
        actions: [
          if (budget != null)
            TextButton(
              onPressed: () async {
                final db = ref.read(databaseProvider);
                await db.budgetDao.deleteBudget(budget!.id);
                if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
              },
              child: const Text('Quitar límite',
                  style: TextStyle(color: AppColors.expense)),
            ),
          TextButton(
            onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
            child: const Text('Cancelar',
                style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () async {
              final text =
                  controller.text.trim().replaceAll(',', '.');
              final amount = double.tryParse(text);
              if (amount == null || amount <= 0) return;

              final db = ref.read(databaseProvider);
              await db.budgetDao.upsert(BudgetsCompanion(
                id: Value(budget?.id ?? const Uuid().v4()),
                year: Value(month.year),
                month: Value(month.month),
                categoryId: Value(category.id),
                limitCents: Value((amount * 100).round()),
                currency: const Value('PEN'),
              ));
              if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}
