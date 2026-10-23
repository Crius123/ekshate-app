import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:go_router/go_router.dart';
import 'cart_controller.dart';
import '../domain/cart_item.dart';
import '../../wallet/presentation/wallet_controller.dart';
import '../../wallet/domain/wallet_state.dart';
import '../../wallet/presentation/widgets/deposit_modal.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/errors/app_exception.dart';

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  bool _isCheckingOut = false;
  String? _checkoutError;

  Future<void> _handleCheckout(String deliveryAddress, String? phone) async {
    setState(() {
      _isCheckingOut = true;
      _checkoutError = null;
    });

    try {
      HapticFeedback.mediumImpact();
      await ref.read(cartProvider.notifier).checkout(
            deliveryAddress: deliveryAddress,
            phone: phone,
          );

      if (!mounted) return;

      // Celebratory Toast
      ShadToaster.of(context).show(
        const ShadToast(
          title: Text('🎉 Batch Order Placed!'),
          description: Text(
            'Funds locked in escrow. Allocation confirmed in active community bucket.',
          ),
        ),
      );

      // Redirect to Orders tab
      context.go(RoutePaths.orders);
    } on InsufficientWalletBalanceException catch (e) {
      HapticFeedback.heavyImpact();
      setState(() {
        _checkoutError = e.message;
      });
      if (mounted) {
        ShadToaster.of(context).show(
          ShadToast.destructive(
            title: const Text('Insufficient Funds'),
            description: Text(e.message),
          ),
        );
      }
    } on BucketCapacityExceededException catch (e) {
      HapticFeedback.heavyImpact();
      setState(() {
        _checkoutError = e.message;
      });
      if (mounted) {
        ShadToaster.of(context).show(
          ShadToast.destructive(
            title: const Text('Bucket Capacity Exceeded'),
            description: Text(e.message),
          ),
        );
      }
    } catch (e) {
      HapticFeedback.heavyImpact();
      setState(() {
        _checkoutError = e.toString();
      });
      if (mounted) {
        ShadToaster.of(context).show(
          ShadToast.destructive(
            title: const Text('Checkout Failed'),
            description: Text(e.toString()),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingOut = false;
        });
      }
    }
  }

  void _showAddressEditDialog(BuildContext context, String currentAddress) {
    final controller = TextEditingController(text: currentAddress);
    showShadDialog(
      context: context,
      builder: (dialogCtx) => ShadDialog(
        title: const Text('Review Delivery Address'),
        description: const Text(
          'Provide the destination address for tomorrow morning fulfillment.',
        ),
        actions: [
          ShadButton.outline(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          ShadButton(
            onPressed: () {
              final newAddress = controller.text.trim();
              if (newAddress.isNotEmpty) {
                final user = ref.read(authStateProvider).asData?.value;
                if (user != null) {
                  ref.read(authStateProvider.notifier).completeProfile(
                        displayName: user.displayName ?? 'Customer',
                        addressLine: newAddress,
                      );
                }
              }
              Navigator.of(dialogCtx).pop();
            },
            child: const Text('Save Address'),
          ),
        ],
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: ShadInput(
            controller: controller,
            placeholder: const Text('Enter full street address, area & city...'),
            maxLines: 3,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final cartItems = ref.watch(cartProvider);
    final totalAmount = ref.watch(cartTotalAmountProvider);
    final wallet = ref.watch(walletBalanceProvider);
    final authUser = ref.watch(authStateProvider).asData?.value;

    final deliveryAddress = authUser?.deliveryAddress?.trim() ?? '';
    final hasValidAddress = deliveryAddress.isNotEmpty;

    final isBalanceSufficient = wallet.available >= totalAmount;
    final deficit = (totalAmount - wallet.available).clamp(0.0, double.infinity);

    return Scaffold(
      appBar: AppBar(
        title: Text('Batch Order Cart', style: theme.textTheme.h4),
        actions: [
          if (cartItems.isNotEmpty)
            IconButton(
              icon: const Icon(LucideIcons.trash2, size: 20),
              tooltip: 'Clear Cart',
              onPressed: () {
                ref.read(cartProvider.notifier).clearCart();
              },
            ),
        ],
      ),
      body: cartItems.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(LucideIcons.shoppingBag, size: 56, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text('Your batch cart is empty', style: theme.textTheme.h4),
                  const SizedBox(height: 8),
                  Text(
                    'Select items from today\'s active campaign wholesale drops',
                    style: theme.textTheme.muted,
                  ),
                  const SizedBox(height: 20),
                  ShadButton(
                    onPressed: () => context.go(RoutePaths.dailySale),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.sparkles, size: 16),
                        SizedBox(width: 8),
                        Text('Explore Wholesale Drops'),
                      ],
                    ),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Reserved Items List Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Reserved Items (${cartItems.length})',
                        style: theme.textTheme.large.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Capacity Clamped',
                        style: theme.textTheme.small.copyWith(color: const Color(0xFF10B981)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 2. Reserved Items Cards
                  ...cartItems.map((item) => _buildCartItemCard(context, theme, item)),

                  const SizedBox(height: 16),

                  // 3. Delivery Address Review Card
                  _buildDeliveryAddressReviewCard(context, theme, deliveryAddress, authUser),

                  const SizedBox(height: 16),

                  // 4. Checkout Breakdown & Dual-Balance Contrast Panel
                  _buildCheckoutSummaryPanel(
                    context,
                    theme,
                    totalAmount: totalAmount,
                    walletAvailable: wallet.available,
                    isBalanceSufficient: isBalanceSufficient,
                    deficit: deficit,
                    hasValidAddress: hasValidAddress,
                    deliveryAddress: deliveryAddress,
                    phone: authUser?.phoneNumber,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildCartItemCard(BuildContext context, ShadThemeData theme, CartItem item) {
    return Container(
      key: Key('cart_item_${item.listingId}'),
      margin: const EdgeInsets.only(bottom: 12.0),
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  item.productTitle,
                  style: theme.textTheme.large.copyWith(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                key: Key('cart_item_remove_${item.listingId}'),
                icon: const Icon(LucideIcons.trash2, size: 18, color: Colors.redAccent),
                onPressed: () {
                  ref.read(cartProvider.notifier).removeItem(item.listingId);
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '৳${item.unitPrice.toStringAsFixed(0)} / ${item.unit}',
                style: theme.textTheme.muted,
              ),
              Text(
                '৳${item.totalAmount.toStringAsFixed(0)}',
                style: theme.textTheme.h4.copyWith(
                  color: const Color(0xFF10B981),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Divider(color: Color(0xFF27272A), height: 20),
          // Quantity Adjuster Stepper
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Allocated Volume (Max: ${item.maxAllowedCapacity.toStringAsFixed(0)} ${item.unit})',
                style: theme.textTheme.small.copyWith(color: const Color(0xFFA1A1AA)),
              ),
              Row(
                children: [
                  IconButton(
                    key: Key('cart_item_minus_${item.listingId}'),
                    icon: const Icon(LucideIcons.minusCircle, size: 22),
                    color: item.quantity > 1.0 ? Colors.white : Colors.grey,
                    onPressed: item.quantity > 1.0
                        ? () {
                            ref
                                .read(cartProvider.notifier)
                                .updateQuantity(item.listingId, item.quantity - 1.0);
                          }
                        : null,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(
                      '${item.quantity.toStringAsFixed(0)} ${item.unit}',
                      key: Key('cart_item_qty_${item.listingId}'),
                      style: theme.textTheme.large.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    key: Key('cart_item_plus_${item.listingId}'),
                    icon: const Icon(LucideIcons.plusCircle, size: 22),
                    color: item.quantity < item.maxAllowedCapacity
                        ? const Color(0xFF10B981)
                        : Colors.grey,
                    onPressed: item.quantity < item.maxAllowedCapacity
                        ? () {
                            ref
                                .read(cartProvider.notifier)
                                .updateQuantity(item.listingId, item.quantity + 1.0);
                          }
                        : null,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryAddressReviewCard(
    BuildContext context,
    ShadThemeData theme,
    String deliveryAddress,
    dynamic authUser,
  ) {
    final hasAddress = deliveryAddress.isNotEmpty;

    return Container(
      key: const Key('delivery_address_review_card'),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasAddress ? const Color(0xFF27272A) : Colors.amber.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.mapPin, size: 18, color: Color(0xFF10B981)),
                  const SizedBox(width: 8),
                  Text(
                    'Delivery Address Review',
                    style: theme.textTheme.large.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              ShadButton.ghost(
                key: const Key('edit_delivery_address_btn'),
                size: ShadButtonSize.sm,
                onPressed: () => _showAddressEditDialog(context, deliveryAddress),
                child: Text(hasAddress ? 'Edit' : 'Add Address'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (hasAddress) ...[
            Text(
              deliveryAddress,
              key: const Key('delivery_address_text'),
              style: theme.textTheme.muted.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 4),
            Text(
              'Recipient: ${authUser?.displayName ?? 'Sheikh Buyer'} • ${authUser?.phoneNumber ?? '+8801711000001'}',
              style: theme.textTheme.small.copyWith(color: const Color(0xFFA1A1AA)),
            ),
          ] else ...[
            Text(
              'No delivery address configured. Please set an address for morning delivery.',
              style: theme.textTheme.small.copyWith(color: Colors.amber),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCheckoutSummaryPanel(
    BuildContext context,
    ShadThemeData theme, {
    required double totalAmount,
    required double walletAvailable,
    required bool isBalanceSufficient,
    required double deficit,
    required bool hasValidAddress,
    required String deliveryAddress,
    String? phone,
  }) {
    return Container(
      key: const Key('cart_summary_panel'),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order & Escrow Summary',
            style: theme.textTheme.large.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          // Subtotal Breakdown
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Items Subtotal:', style: theme.textTheme.muted),
              Text(
                '৳${totalAmount.toStringAsFixed(0)}',
                key: const Key('cart_subtotal_text'),
                style: theme.textTheme.large,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Community Escrow Protection:', style: theme.textTheme.muted),
              const Text('৳0 (Free)', style: TextStyle(color: Color(0xFF10B981))),
            ],
          ),
          const Divider(color: Color(0xFF27272A), height: 24),

          // Contrast: Available Balance vs Total Escrow Required
          Container(
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: const Color(0xFF111113),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isBalanceSufficient
                    ? const Color(0xFF10B981).withValues(alpha: 0.3)
                    : Colors.redAccent.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Customer Available Balance:', style: theme.textTheme.muted),
                    Text(
                      '৳${walletAvailable.toStringAsFixed(0)}',
                      key: const Key('cart_wallet_available_text'),
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
                    Text(
                      'Total Escrow Required:',
                      style: theme.textTheme.h4.copyWith(fontSize: 16),
                    ),
                    Text(
                      '৳${totalAmount.toStringAsFixed(0)}',
                      key: const Key('cart_total_escrow_text'),
                      style: theme.textTheme.h3.copyWith(
                        color: const Color(0xFF10B981),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Insufficient Balance Deficit Alert Banner with 1-Tap bKash Top-up
          if (!isBalanceSufficient) ...[
            Container(
              key: const Key('insufficient_balance_alert'),
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(LucideIcons.alertTriangle, size: 18, color: Colors.redAccent),
                      const SizedBox(width: 8),
                      Text(
                        'Insufficient Available Balance',
                        style: theme.textTheme.large.copyWith(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'You need ৳${deficit.toStringAsFixed(0)} more in your available wallet to escrow funds for this batch reservation.',
                    style: theme.textTheme.small.copyWith(color: const Color(0xFFA1A1AA)),
                  ),
                  const SizedBox(height: 10),
                  // 1-Tap bKash Shortcut Button
                  SizedBox(
                    width: double.infinity,
                    child: ShadButton(
                      key: const Key('cart_topup_bkash_btn'),
                      backgroundColor: const Color(0xFFE2136E), // bKash brand pink
                      foregroundColor: Colors.white,
                      onPressed: () {
                        DepositModal.show(
                          context,
                          initialGateway: DepositGateway.bkash,
                          initialAmount: deficit,
                        );
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(LucideIcons.zap, size: 16),
                          const SizedBox(width: 8),
                          Text('Top-up ৳${deficit.toStringAsFixed(0)} via bKash'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          if (_checkoutError != null) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Text(
                _checkoutError!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 13),
              ),
            ),
          ],

          // Checkout Button: Confirm & Escrow Funds
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ShadButton(
              key: const Key('confirm_escrow_funds_btn'),
              enabled: isBalanceSufficient &&
                  hasValidAddress &&
                  !_isCheckingOut &&
                  totalAmount > 0,
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              onPressed: () => _handleCheckout(deliveryAddress, phone),
              child: _isCheckingOut
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 10),
                        Text('Escrowing Funds...'),
                      ],
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(LucideIcons.lock, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Confirm & Escrow Funds',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
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
