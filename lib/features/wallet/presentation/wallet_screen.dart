import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/route_paths.dart';
import '../../auth/presentation/auth_controller.dart';
import 'wallet_controller.dart';

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ShadTheme.of(context);
    final wallet = ref.watch(walletBalanceProvider);
    final transactions = ref.watch(walletTransactionsProvider);
    final authState = ref.watch(authStateProvider);
    final profile = authState.asData?.value;

    return Scaffold(
      appBar: AppBar(
        title: Text('Wallet & Escrow', style: theme.textTheme.h4),
        actions: [
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
                      const Icon(LucideIcons.user, size: 18),
                      const SizedBox(width: 8),
                      Text(profile.displayName ?? 'Customer', style: theme.textTheme.small),
                    ],
                  ),
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
              description: Text(
                '${profile.phoneNumber ?? ''} • ${profile.deliveryAddress ?? 'No address set'}',
                style: theme.textTheme.muted,
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
          // Balances Card
          Row(
            children: [
              Expanded(
                child: ShadCard(
                  title: Text('Available Balance', style: theme.textTheme.small),
                  description: Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      '৳${wallet.available.toStringAsFixed(0)}',
                      style: theme.textTheme.h2.copyWith(color: const Color(0xFF10B981)),
                    ),
                  ),
                  footer: Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text('Free for orders & withdraw', style: theme.textTheme.muted),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ShadCard(
                  title: Text('Escrow Balance', style: theme.textTheme.small),
                  description: Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      '৳${wallet.escrow.toStringAsFixed(0)}',
                      style: theme.textTheme.h2.copyWith(color: const Color(0xFFF59E0B)),
                    ),
                  ),
                  footer: Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text('Locked in active buckets', style: theme.textTheme.muted),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Top Up Action Card
          ShadCard(
            title: Text('Deposit Funds', style: theme.textTheme.large),
            description: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                'Instant deposits with zero surcharge via bKash Tokenized Checkout or SSLCommerz.',
                style: theme.textTheme.muted,
              ),
            ),
            footer: Row(
              children: [
                Expanded(
                  child: ShadButton(
                    onPressed: () {
                      ShadToaster.of(context).show(
                        const ShadToast(
                          title: Text('bKash Checkout Initiated'),
                          description: Text('Redirecting to secure bKash payment gateway...'),
                        ),
                      );
                    },
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(LucideIcons.wallet, size: 16),
                        SizedBox(width: 8),
                        Text('Top-up with bKash'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ShadButton.outline(
                    onPressed: () {
                      ShadToaster.of(context).show(
                        const ShadToast(
                          title: Text('SSLCommerz Initiated'),
                          description: Text('Redirecting to SSLCommerz gateway...'),
                        ),
                      );
                    },
                    child: const Text('SSLCommerz'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Audit Ledger Section
          Text('Transaction Audit Ledger', style: theme.textTheme.h4),
          const SizedBox(height: 12),

          if (transactions.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text('No transactions recorded', style: theme.textTheme.muted),
              ),
            )
          else
            ...transactions.map((tx) {
              final isCredit = tx.amount > 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: ShadCard(
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isCredit ? LucideIcons.arrowDownLeft : LucideIcons.arrowUpRight,
                            color: isCredit ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(tx.type.replaceAll('_', ' ').toUpperCase(), style: theme.textTheme.small),
                        ],
                      ),
                      Text(
                        '${isCredit ? '+' : ''}৳${tx.amount.abs().toStringAsFixed(0)}',
                        style: theme.textTheme.large.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isCredit ? const Color(0xFF10B981) : Colors.white70,
                        ),
                      ),
                    ],
                  ),
                  description: Text(
                    'TrxID: ${tx.trxId} • ${tx.createdAt.hour}:${tx.createdAt.minute.toString().padLeft(2, '0')}',
                    style: theme.textTheme.muted,
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
