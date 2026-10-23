import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../../../core/router/route_paths.dart';
import '../../auth/presentation/auth_controller.dart';
import 'admin_controller.dart';
import 'widgets/overview_monitor_tab.dart';
import 'widgets/daily_deal_scheduler_tab.dart';
import 'widgets/withdrawal_payouts_tab.dart';

class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final userProfile = ref.watch(authStateProvider).asData?.value;
    final metricsAsync = ref.watch(adminMetricsProvider);

    // Defense-in-depth: if not admin, show access denied view
    if (userProfile == null || userProfile.role != 'admin') {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Access Denied'),
          leading: IconButton(
            icon: const Icon(LucideIcons.arrowLeft),
            onPressed: () => context.go(RoutePaths.dailySale),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(LucideIcons.shieldAlert, size: 56, color: Colors.redAccent),
                const SizedBox(height: 16),
                Text('Administrator Access Required', style: theme.textTheme.h3),
                const SizedBox(height: 8),
                Text(
                  'Your current account (${userProfile?.displayName ?? 'Customer'}) does not have platform administrative privileges.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.muted,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  key: const Key('switch_to_admin_role_button'),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                  onPressed: () {
                    ref.read(authStateProvider.notifier).switchRole('admin');
                  },
                  icon: const Icon(LucideIcons.shieldCheck, size: 18),
                  label: const Text('Switch Role to Admin (Dev/Operator Mode)'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => context.go(RoutePaths.dailySale),
                  child: const Text('Return to Storefront'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Admin Console', style: theme.textTheme.h4),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                  ),
                  child: const Text(
                    'OPERATOR',
                    style: TextStyle(
                      color: Color(0xFF10B981),
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              'Campaign Momentum & Financial Review',
              style: theme.textTheme.muted.copyWith(fontSize: 11),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          tooltip: 'Back to Client App',
          onPressed: () => context.go(RoutePaths.dailySale),
        ),
        actions: [
          // Quick Role Toggle to return to customer
          TextButton.icon(
            key: const Key('switch_to_customer_button'),
            icon: const Icon(LucideIcons.user, size: 16),
            label: const Text('Customer Mode', style: TextStyle(fontSize: 12)),
            onPressed: () {
              ref.read(authStateProvider.notifier).switchRole('customer');
              context.go(RoutePaths.wallet);
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF10B981),
          labelColor: const Color(0xFF10B981),
          unselectedLabelColor: const Color(0xFF94A3B8),
          tabs: const [
            Tab(
              key: Key('tab_overview_monitor'),
              icon: Icon(LucideIcons.activity, size: 16),
              text: 'Overview',
            ),
            Tab(
              key: Key('tab_deal_scheduler'),
              icon: Icon(LucideIcons.calendarPlus, size: 16),
              text: 'Scheduler',
            ),
            Tab(
              key: Key('tab_withdrawal_payouts'),
              icon: Icon(LucideIcons.wallet, size: 16),
              text: 'Withdrawals',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Overview & Operational Monitor
          metricsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Error loading metrics: $err')),
            data: (metrics) => OverviewMonitorTab(metrics: metrics),
          ),

          // Tab 2: Daily Deal Scheduler
          const DailyDealSchedulerTab(),

          // Tab 3: Wallet Withdrawal & Payouts Tab
          const WithdrawalPayoutsTab(),
        ],
      ),
    );
  }
}
