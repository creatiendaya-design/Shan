import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../app/theme/app_colors.dart';
import '../../data/local/app_database.dart';
import '../../shared/providers/transaction_providers.dart';
import '../../shared/providers/database_provider.dart';
import 'add_transaction_sheet.dart';
import 'edit_transaction_sheet.dart';

final _selectedMonthProvider = StateProvider<DateTime>((ref) => DateTime.now());
final _filterTypeProvider    = StateProvider<String?>((ref) => null);
final _searchQueryProvider   = StateProvider<String>((ref) => '');

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  bool _showSearch = false;
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() => _showSearch = !_showSearch);
    if (!_showSearch) {
      _searchCtrl.clear();
      ref.read(_searchQueryProvider.notifier).state = '';
    }
  }

  List<Transaction> _applyFilters(
    List<Transaction> txs,
    String? type,
    String query,
    List<Category> categories,
  ) {
    var result = txs;
    if (type != null) result = result.where((t) => t.type == type).toList();
    if (query.isNotEmpty) {
      final q = query.toLowerCase();
      result = result.where((t) {
        final noteMatch = t.note?.toLowerCase().contains(q) ?? false;
        final cat = categories.where((c) => c.id == t.categoryId).firstOrNull;
        final catMatch = cat?.name.toLowerCase().contains(q) ?? false;
        return noteMatch || catMatch;
      }).toList();
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final selectedMonth = ref.watch(_selectedMonthProvider);
    final filterType    = ref.watch(_filterTypeProvider);
    final query         = ref.watch(_searchQueryProvider);
    final categories    = ref.watch(categoriesProvider).valueOrNull ?? [];
    final txAsync = ref.watch(transactionsByMonthProvider(
        (selectedMonth.year, selectedMonth.month)));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: _showSearch
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Buscar…',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: AppColors.textMuted),
                ),
                onChanged: (v) =>
                    ref.read(_searchQueryProvider.notifier).state = v,
              )
            : Text('Gastos', style: Theme.of(context).textTheme.headlineMedium),
        actions: [
          IconButton(
            icon: Icon(
              _showSearch ? Icons.close : Icons.search,
              color: AppColors.textSecondary,
            ),
            onPressed: _toggleSearch,
          ),
          if (!_showSearch)
            IconButton(
              icon: const Icon(Icons.add, color: AppColors.primary),
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const AddTransactionSheet(),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          _MonthSelector(selected: selectedMonth),
          _FilterChips(filterType: filterType),
          Expanded(
            child: txAsync.when(
              data: (txs) {
                final filtered = _applyFilters(txs, filterType, query, categories);
                final isFiltered = filterType != null || query.isNotEmpty;
                return filtered.isEmpty
                    ? _EmptyState(month: selectedMonth, isFiltered: isFiltered)
                    : _TransactionList(transactions: filtered);
              },
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
              error: (e, st) => const SizedBox(),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Chips de filtro ──────────────────────────────────────────────────────────

class _FilterChips extends ConsumerWidget {
  final String? filterType;
  const _FilterChips({required this.filterType});

  static const _chips = [
    (null, 'Todos'),
    ('expense', 'Gastos'),
    ('income', 'Ingresos'),
    ('transfer', 'Transferencias'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: _chips.map((c) {
          final sel = filterType == c.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () =>
                  ref.read(_filterTypeProvider.notifier).state = c.$1,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: sel
                      ? AppColors.primary.withValues(alpha: 0.15)
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: sel ? AppColors.primary : AppColors.border),
                ),
                child: Text(
                  c.$2,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                    color: sel ? AppColors.primary : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
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
                .read(_selectedMonthProvider.notifier)
                .state = DateTime(selected.year, selected.month - 1),
            icon: const Icon(Icons.chevron_left, color: AppColors.textSecondary),
          ),
          Text(
            fmt.format(selected),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          IconButton(
            onPressed: selected.year == DateTime.now().year &&
                    selected.month == DateTime.now().month
                ? null
                : () => ref
                    .read(_selectedMonthProvider.notifier)
                    .state = DateTime(selected.year, selected.month + 1),
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

// ── Lista agrupada por día ───────────────────────────────────────────────────

class _TransactionList extends ConsumerWidget {
  final List<Transaction> transactions;
  const _TransactionList({required this.transactions});

  Map<String, List<Transaction>> _groupByDay(List<Transaction> txs) {
    final Map<String, List<Transaction>> grouped = {};
    for (final tx in txs) {
      final date = DateTime.fromMillisecondsSinceEpoch(tx.date);
      final key = DateFormat('yyyy-MM-dd').format(date);
      grouped.putIfAbsent(key, () => []).add(tx);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grouped = _groupByDay(transactions);
    final days = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 100),
      itemCount: days.length,
      itemBuilder: (context, i) {
        final day = days[i];
        final dayTxs = grouped[day]!;
        final date = DateTime.parse(day);
        final dayTotal = dayTxs.fold<int>(0, (sum, tx) {
          if (tx.type == 'income') return sum + tx.amountCents;
          if (tx.type == 'expense') return sum - tx.amountCents;
          return sum;
        });

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DayHeader(date: date, totalCents: dayTotal),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: dayTxs.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final tx = entry.value;
                  return Column(
                    children: [
                      _SwipeableTile(tx: tx),
                      if (idx < dayTxs.length - 1)
                        const Divider(
                            height: 1, indent: 56, color: AppColors.border),
                    ],
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
          ],
        );
      },
    );
  }
}

class _DayHeader extends StatelessWidget {
  final DateTime date;
  final int totalCents;

  const _DayHeader({required this.date, required this.totalCents});

  String _label(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final d = DateTime(date.year, date.month, date.day);
    if (d == today) return 'Hoy';
    if (d == yesterday) return 'Ayer';
    return DateFormat('EEEE d', 'es').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: 'S/ ', decimalDigits: 2);
    final isPositive = totalCents >= 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            _label(date),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w600,
                ),
          ),
          Text(
            fmt.format(totalCents.abs() / 100),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: isPositive ? AppColors.income : AppColors.expense,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

// ── Tile con swipe para eliminar ─────────────────────────────────────────────

class _SwipeableTile extends ConsumerWidget {
  final Transaction tx;
  const _SwipeableTile({required this.tx});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dismissible(
      key: Key(tx.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.expense.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: AppColors.expense),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: AppColors.surface,
            title: const Text('Eliminar transacción'),
            content: const Text('¿Seguro que quieres eliminar este movimiento?'),
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
                child: const Text('Eliminar'),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) async {
        final db = ref.read(databaseProvider);
        await db.transactionDao.deleteTransaction(tx.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Transacción eliminada'),
              backgroundColor: AppColors.surface,
            ),
          );
        }
      },
      child: _TransactionTile(tx: tx),
    );
  }
}

class _TransactionTile extends ConsumerWidget {
  final Transaction tx;
  const _TransactionTile({required this.tx});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = NumberFormat.currency(symbol: 'S/ ', decimalDigits: 2);
    final isIncome = tx.type == 'income';
    final isTransfer = tx.type == 'transfer';
    final color = isTransfer
        ? AppColors.primaryLight
        : isIncome
            ? AppColors.income
            : AppColors.expense;
    final sign = isIncome ? '+' : isTransfer ? '↔' : '-';

    final categories = ref.watch(categoriesProvider).valueOrNull ?? [];
    final category =
        categories.where((c) => c.id == tx.categoryId).firstOrNull;

    return ListTile(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => EditTransactionSheet(transaction: tx),
      ),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          isIncome
              ? Icons.arrow_downward
              : isTransfer
                  ? Icons.swap_horiz
                  : Icons.arrow_upward,
          color: color,
          size: 18,
        ),
      ),
      title: Text(
        category?.name ?? (isTransfer ? 'Transferencia' : 'Sin categoría'),
        style: Theme.of(context).textTheme.bodyLarge,
      ),
      subtitle: tx.note != null
          ? Text(tx.note!, style: Theme.of(context).textTheme.labelSmall)
          : null,
      trailing: Text(
        '$sign${fmt.format(tx.amountCents / 100)}',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
      ),
    );
  }
}

// ── Estado vacío ─────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final DateTime month;
  final bool isFiltered;
  const _EmptyState({required this.month, this.isFiltered = false});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('MMMM', 'es');
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isFiltered ? Icons.filter_list_off : Icons.receipt_long_outlined,
            size: 64, color: AppColors.textMuted,
          ),
          const SizedBox(height: 16),
          Text(
            isFiltered
                ? 'Sin resultados'
                : 'Sin movimientos en ${fmt.format(month)}',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 8),
          Text(
            isFiltered
                ? 'Prueba con otro filtro o búsqueda'
                : 'Toca + para agregar un gasto o ingreso',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
