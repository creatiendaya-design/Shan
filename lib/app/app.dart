import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/local/app_database.dart';
import '../features/notifications/notification_service.dart';
import '../features/recurring/recurring_service.dart';
import '../features/security/lock_screen.dart';
import '../shared/providers/database_provider.dart';
import '../shared/providers/security_provider.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

class ShannonApp extends ConsumerWidget {
  const ShannonApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(dbInitProvider);

    return MaterialApp.router(
      title: 'Shannon',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark.copyWith(
        textTheme: GoogleFonts.ibmPlexSansTextTheme(AppTheme.dark.textTheme),
      ),
      routerConfig: router,
    );
  }
}

class ShannonRoot extends ConsumerStatefulWidget {
  const ShannonRoot({super.key});

  @override
  ConsumerState<ShannonRoot> createState() => _ShannonRootState();
}

class _ShannonRootState extends ConsumerState<ShannonRoot>
    with WidgetsBindingObserver {
  bool _unlocked = false;
  bool _wasBackground = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkSecurity();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _wasBackground = true;
    } else if (state == AppLifecycleState.resumed && _wasBackground) {
      _wasBackground = false;
      _recheckSecurity();
    }
  }

  Future<void> _checkSecurity() async {
    final service = ref.read(securityServiceProvider);
    final type = await service.getSecurityType();
    if (type == 'none') {
      setState(() => _unlocked = true);
      _applyRecurring();
    }
    // LockScreen maneja el resto
  }

  Future<void> _applyRecurring() async {
    final db = ref.read(databaseProvider);
    await applyDueRecurring(db);
    _scheduleStartupNotifications(db);
  }

  Future<void> _scheduleStartupNotifications(AppDatabase db) async {
    final debts = await db.debtDao.watchAll().first;
    await scheduleDebtNotifications(debts);

    final now = DateTime.now();
    final budgets = await db.budgetDao.getByMonth(now.year, now.month);
    final spentByCat =
        await db.transactionDao.sumByCategoryAndMonth(now.year, now.month);
    final categories = await db.categoryDao.watchAll().first;
    await checkBudgetAlerts(budgets, spentByCat, categories);
  }

  Future<void> _recheckSecurity() async {
    final service = ref.read(securityServiceProvider);
    final type = await service.getSecurityType();
    if (type != 'none') {
      setState(() => _unlocked = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_unlocked) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: LockScreen(onUnlocked: () {
          setState(() => _unlocked = true);
          _applyRecurring();
        }),
      );
    }
    return const ShannonApp();
  }
}
