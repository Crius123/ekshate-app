import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/config/theme/app_decorations.dart';
import '../../notifications/presentation/widgets/notification_bell_button.dart';
import '../../notifications/presentation/widgets/notification_preferences_modal.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/wallet_state.dart';
import 'wallet_controller.dart';
import 'widgets/deposit_modal.dart';

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ShadToaster.of(context).show(
      ShadToast(
        title: Text('$label Copied'),
        description: Text(text),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ShadTheme.of(context);
    final wallet = ref.watch(walletBalanceProvider);
    final transactions = ref.watch(filteredTransactionsProvider);
    final authState = ref.watch(authStateProvider);
    final profile = authState.asData?.value;

    final dateFormat = DateFormat('d MMM, h:mm a');

    return Scaffold(
      appBar: AppBar(
        title: Text('Wallet & Escrow', style: theme.textTheme.h4),
        actions: [
          const NotificationBellButton(),
          if (profile != null)
            IconButton(
              icon: const Icon(LucideIcons.logOut, size: 20),
              tooltip: 'Sign Out',
              onPressed: () async {
                await ref.read(authStateProvider.notifier).signOut();
                if (context.mounted) {
                  context.go(RoutePaths.login);
                }
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Customer Profile Card
          if (profile != null) ...[
            ShadCard(
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(LucideIcons.user, size: 16, color: theme.colorScheme.primary),
                      ),
                      const SizedBox(width: 8),
                      Text(profile.displayName ?? 'Customer', style: theme.textTheme.small),
                    ],
                  ),
                  Row(
                    children: [
                      InkWell(
                        onTap: () => NotificationPreferencesModal.show(context),
                        child: Text(
                          'Push Alerts',
                          style: theme.textTheme.small.copyWith(
                            color: theme.colorScheme.primary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      InkWell(
                        onTap: () => context.push(RoutePaths.profileSetup),
                        child: Text(
                          'Edit Address',
                          style: theme.textTheme.small.copyWith(
                            color: theme.colorScheme.primary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              description: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${profile.phoneNumber ?? ''} • ${profile.deliveryAddress ?? 'No address set'}',
                    style: theme.textTheme.muted,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (profile.role == 'admin') ...[
                        ElevatedButton.icon(
                          key: const Key('admin_dashboard_entry_button'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          icon: const Icon(LucideIcons.shieldCheck, size: 14),
                          label: const Text('Admin Dashboard'),
                          onPressed: () => context.push(RoutePaths.admin),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          key: const Key('quick_switch_role_button'),
                          onPressed: () => ref.read(authStateProvider.notifier).switchRole('customer'),
                          child: const Text('Switch to Customer Role', style: TextStyle(fontSize: 11)),
                        ),
                      ] else ...[
                        OutlinedButton.icon(
                          key: const Key('quick_switch_role_button'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          ),
                          icon: const Icon(LucideIcons.shield, size: 12),
                          label: const Text('Operator Mode: Switch to Admin', style: TextStyle(fontSize: 11)),
                          onPressed: () {
                            ref.read(authStateProvider.notifier).switchRole('admin');
                            context.push(RoutePaths.admin);
                          },
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ] else ...[
            ShadCard(
              title: const Text('Not Signed In'),
              description: const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text('Sign in with your mobile number to view balances and place community bulk orders.'),
              ),
              child: ShadButton(
                onPressed: () => context.push(RoutePaths.login),
                child: const Text('Sign In with SMS OTP'),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Prominent Dual-Balance Display Cards
          Row(
            children: [
              // Available Balance Card (Emerald)
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: AppDecorations.glassCard(
                    surfaceColor: const Color(0xFFECFDF5),
                    borderColor: AppColors.emerald.withValues(alpha: 0.4),
                    borderRadius: 16,
                    hasGlow: true,
                    glowColor: AppColors.emeraldGlow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Available Balance',
                            style: theme.textTheme.small.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.emerald,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: AppColors.emerald,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(LucideIcons.check, size: 12, color: Colors.white),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '৳${wallet.available.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: AppColors.emerald,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Free for orders & withdraw',
                        style: theme.textTheme.muted.copyWith(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Escrow Balance Card (Amber)
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: AppDecorations.glassCard(
                    surfaceColor: const Color(0xFFFFFBEB),
                    borderColor: AppColors.amberEscrow.withValues(alpha: 0.4),
                    borderRadius: 16,
                    hasGlow: true,
                    glowColor: AppColors.amberGlow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Escrow Balance',
                            style: theme.textTheme.small.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.amberEscrow,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: AppColors.amberEscrow,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(LucideIcons.lock, size: 12, color: Colors.white),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '৳${wallet.escrow.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: AppColors.amberEscrow,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Locked in active batch deals',
                        style: theme.textTheme.muted.copyWith(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Deposit Action Card
          ShadCard(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Deposit Funds', style: theme.textTheme.large),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Instant • Zero Fee',
                    style: TextStyle(
                      color: Color(0xFF10B981),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            description: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                'Instant deposits backed by write-once ledger idempotency via bKash Tokenized Checkout or SSLCommerz.',
                style: theme.textTheme.muted,
              ),
            ),
            footer: Row(
              children: [
                Expanded(
                  child: ShadButton(
                    backgroundColor: const Color(0xFFE2136E),
                    onPressed: () => DepositModal.show(context, initialGateway: DepositGateway.bkash),
                    child: const Text('bKash Top-up'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ShadButton.outline(
                    onPressed: () => DepositModal.show(context, initialGateway: DepositGateway.sslcommerz),
                    child: const Text('SSLCommerz'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Audit Ledger Header and Filter Chips
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Transaction Audit Ledger', style: theme.textTheme.h4),
              Text(
                '${transactions.length} record${transactions.length == 1 ? '' : 's'}',
                style: theme.textTheme.muted,
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Filter Segmented Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(ref, 'all', 'All'),
                const SizedBox(width: 6),
                _buildFilterChip(ref, 'top_up', 'Deposits'),
                const SizedBox(width: 6),
                _buildFilterChip(ref, 'order_hold', 'Escrow Holds'),
                const SizedBox(width: 6),
                _buildFilterChip(ref, 'order_settle', 'Settled'),
                const SizedBox(width: 6),
                _buildFilterChip(ref, 'order_refund', 'Refunds'),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Transaction Ledger List
          if (transactions.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  children: [
                    const Icon(LucideIcons.receipt, size: 36, color: AppColors.textMuted),
                    const SizedBox(height: 10),
                    Text('No transactions found', style: theme.textTheme.muted),
                  ],
                ),
              ),
            )
          else
            ...transactions.map((tx) {
              final isCredit = tx.amount > 0;
              final Color badgeColor;
              final IconData icon;

              switch (tx.type) {
                case 'top_up':
                  badgeColor = const Color(0xFF10B981); // Emerald
                  icon = LucideIcons.arrowDownLeft;
                  break;
                case 'order_hold':
                  badgeColor = const Color(0xFFF59E0B); // Amber
                  icon = LucideIcons.lock;
                  break;
                case 'order_settle':
                  badgeColor = const Color(0xFF38BDF8); // Sky blue
                  icon = LucideIcons.checkCheck;
                  break;
                case 'order_refund':
                  badgeColor = const Color(0xFFA855F7); // Purple
                  icon = LucideIcons.rotateCcw;
                  break;
                default:
                  badgeColor = AppColors.textMuted;
                  icon = LucideIcons.arrowRight;
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: AppDecorations.glassCard(
                    surfaceColor: AppColors.cardSurface,
                    borderColor: AppColors.borderSubtle,
                    borderRadius: 12,
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: badgeColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(icon, color: badgeColor, size: 16),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tx.typeLabel,
                                    style: theme.textTheme.small.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    dateFormat.format(tx.createdAt),
                                    style: theme.textTheme.muted.copyWith(
                                      fontSize: 11,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Text(
                            tx.formattedAmount,
                            style: theme.textTheme.large.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isCredit ? AppColors.emerald : AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Copyable Transaction ID Bar
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.cardSurfaceElevated,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.borderSubtle, width: 0.8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                'TrxID: ${tx.trxId}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              icon: const Icon(LucideIcons.copy, size: 13, color: AppColors.textMuted),
                              tooltip: 'Copy TrxID',
                              onPressed: () => _copyToClipboard(context, tx.trxId, 'Transaction ID'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildFilterChip(WidgetRef ref, String id, String label) {
    final current = ref.watch(transactionFilterProvider);
    final isSelected = current == id;

    return InkWell(
      onTap: () => ref.read(transactionFilterProvider.notifier).state = id,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.emerald : AppColors.cardSurfaceElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.emerald : AppColors.borderSubtle,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}
