import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:go_router/go_router.dart';
import 'cart_controller.dart';
import '../../wallet/presentation/wallet_controller.dart';
import '../../../core/router/route_paths.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ShadTheme.of(context);
    final cartItems = ref.watch(cartProvider);
    final totalAmount = ref.watch(cartTotalAmountProvider);
    final wallet = ref.watch(walletBalanceProvider);
    final isBalanceSufficient = wallet.available >= totalAmount;

    return Scaffold(
      appBar: AppBar(
        title: Text('Batch Order Cart', style: theme.textTheme.h4),
      ),
      body: cartItems.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(LucideIcons.shoppingBag, size: 48, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text('Your batch cart is empty', style: theme.textTheme.h4),
                  const SizedBox(height: 8),
                  Text('Select items from today\'s active campaign', style: theme.textTheme.muted),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: cartItems.length,
                    itemBuilder: (context, index) {
                      final item = cartItems[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: ShadCard(
                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(item.productTitle, style: theme.textTheme.large),
                              IconButton(
                                icon: const Icon(LucideIcons.trash2, size: 16, color: Colors.redAccent),
                                onPressed: () {
                                  ref.read(cartProvider.notifier).removeItem(item.listingId);
                                },
                              ),
                            ],
                          ),
                          description: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('${item.quantity.toStringAsFixed(0)} ${item.unit} @ ৳${item.unitPrice.toStringAsFixed(0)}'),
                              Text(
                                '৳${item.totalAmount.toStringAsFixed(0)}',
                                style: theme.textTheme.h4.copyWith(color: const Color(0xFF10B981)),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // Checkout bottom panel
                Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.card,
                    border: Border(top: BorderSide(color: theme.colorScheme.border)),
                  ),
                  child: SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Wallet Balance Status
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Wallet Available Balance:', style: theme.textTheme.muted),
                            Text(
                              '৳${wallet.available.toStringAsFixed(0)}',
                              style: theme.textTheme.large.copyWith(
                                color: isBalanceSufficient ? const Color(0xFF10B981) : Colors.redAccent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Total Escrow Required:', style: theme.textTheme.h4),
                            Text(
                              '৳${totalAmount.toStringAsFixed(0)}',
                              style: theme.textTheme.h3.copyWith(color: const Color(0xFF10B981)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (!isBalanceSufficient)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: ShadAlert.destructive(
                              icon: const Icon(LucideIcons.alertTriangle, size: 16),
                              title: const Text('Insufficient Wallet Balance'),
                              description: Text(
                                'Please top up ৳${(totalAmount - wallet.available).toStringAsFixed(0)} to complete escrow reservation.',
                              ),
                            ),
                          ),
                        Row(
                          children: [
                            if (!isBalanceSufficient) ...[
                              Expanded(
                                child: ShadButton.outline(
                                  onPressed: () => context.push(RoutePaths.wallet),
                                  child: const Text('Top-up via bKash'),
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                            Expanded(
                              child: ShadButton(
                                enabled: isBalanceSufficient && cartItems.isNotEmpty,
                                onPressed: () {
                                  // Dispatch atomic checkout
                                  ref.read(cartProvider.notifier).clearCart();
                                  ShadToaster.of(context).show(
                                    const ShadToast(
                                      title: Text('Order Submitted to Batch Bucket'),
                                      description: Text('Funds reserved in escrow. Awaiting bucket MOQ completion.'),
                                    ),
                                  );
                                  context.go(RoutePaths.orders);
                                },
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(LucideIcons.lock, size: 16),
                                    SizedBox(width: 8),
                                    Text('Confirm & Escrow Funds'),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
