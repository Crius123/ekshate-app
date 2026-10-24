import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:ekshate_app/core/config/theme/app_decorations.dart';
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
            'Payment held safely. Allocation confirmed in active community group.',
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
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 24.0),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24.0),
                  padding: const EdgeInsets.all(32.0),
                  constraints: const BoxConstraints(maxWidth: 560),
                  decoration: AppDecorations.glassCard(
                    surfaceColor: AppColors.cardSurface,
                    borderColor: AppColors.borderSubtle,
                    borderRadius: 20,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.emerald.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(LucideIcons.shoppingBag, size: 48, color: AppColors.emerald),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Your batch cart is empty',
                        style: theme.textTheme.h4.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Select items from today\'s active campaign wholesale drops',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.muted.copyWith(color: AppColors.textMuted),
                      ),
                      const SizedBox(height: 24),
                      ShadButton(
                        backgroundColor: AppColors.emerald,
                        foregroundColor: Colors.white,
                        onPressed: () => context.go(RoutePaths.dailySale),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.sparkles, size: 16),
                            SizedBox(width: 8),
                            Text(
                              'Explore Wholesale Drops',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
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
      padding: const EdgeInsets.all(16.0),
      decoration: AppDecorations.glassCard(
        surfaceColor: AppColors.cardSurface,
        borderColor: AppColors.borderSubtle,
        borderRadius: 14,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product Image on the left-hand side
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 76,
              height: 76,
              color: const Color(0xFFF1F5F9),
              child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                  ? Image.network(
                      item.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: AppColors.emerald.withValues(alpha: 0.1),
                        child: const Center(
                          child: Icon(
                            LucideIcons.shoppingBasket,
                            size: 30,
                            color: AppColors.emerald,
                          ),
                        ),
                      ),
                    )
                  : Container(
                      color: AppColors.emerald.withValues(alpha: 0.1),
                      child: const Center(
                        child: Icon(
                          LucideIcons.shoppingBasket,
                          size: 30,
                          color: AppColors.emerald,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 14),

          // Product Details & Stepper
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        item.productTitle,
                        style: theme.textTheme.large.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      key: Key('cart_item_remove_${item.listingId}'),
                      icon: const Icon(LucideIcons.trash2, size: 18, color: Color(0xFFEF4444)),
                      tooltip: 'Remove',
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
                      style: theme.textTheme.muted.copyWith(color: AppColors.textMuted),
                    ),
                    Text(
                      '৳${item.totalAmount.toStringAsFixed(0)}',
                      style: theme.textTheme.h4.copyWith(
                        color: AppColors.emerald,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const Divider(color: AppColors.borderSubtle, height: 22),
                // Quantity Adjuster Stepper
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Allocated Volume (Max: ${item.maxAllowedCapacity.toStringAsFixed(0)} ${item.unit})',
                      style: theme.textTheme.small.copyWith(color: AppColors.textMuted),
                    ),
                    Row(
                      children: [
                        IconButton(
                          key: Key('cart_item_minus_${item.listingId}'),
                          icon: const Icon(LucideIcons.minusCircle, size: 22),
                          color: item.quantity > 1.0 ? AppColors.textPrimary : Colors.grey,
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
                            style: theme.textTheme.large.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        IconButton(
                          key: Key('cart_item_plus_${item.listingId}'),
                          icon: const Icon(LucideIcons.plusCircle, size: 22),
                          color: item.quantity < item.maxAllowedCapacity
                              ? AppColors.emerald
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
      decoration: AppDecorations.glassCard(
        surfaceColor: AppColors.cardSurface,
        borderColor: hasAddress
            ? AppColors.borderSubtle
            : AppColors.amberEscrow.withValues(alpha: 0.6),
        borderRadius: 14,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.mapPin, size: 18, color: AppColors.emerald),
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
              style: theme.textTheme.muted.copyWith(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              'Recipient: ${authUser?.displayName ?? 'Sheikh Buyer'} • ${authUser?.phoneNumber ?? '+8801711000001'}',
              style: theme.textTheme.small.copyWith(color: AppColors.textMuted),
            ),
          ] else ...[
            Text(
              'No delivery address configured. Please set an address for morning delivery.',
              style: theme.textTheme.small.copyWith(color: AppColors.amberEscrow),
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
      padding: const EdgeInsets.all(18.0),
      decoration: AppDecorations.glassCard(
        surfaceColor: AppColors.cardSurface,
        borderColor: AppColors.borderSubtle,
        borderRadius: 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order Summary',
            style: theme.textTheme.large.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 14),

          // Subtotal Breakdown
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Items Subtotal:', style: theme.textTheme.muted),
              Text(
                '৳${totalAmount.toStringAsFixed(0)}',
                key: const Key('cart_subtotal_text'),
                style: theme.textTheme.large.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('100% Buyer Protection:', style: theme.textTheme.muted),
              const Text(
                '৳0 (Free)',
                style: TextStyle(
                  color: AppColors.emerald,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const Divider(color: AppColors.borderSubtle, height: 24),

          // Contrast: Available Balance vs Total Amount Required
          Container(
            padding: const EdgeInsets.all(14.0),
            decoration: BoxDecoration(
              color: AppColors.cardSurfaceElevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isBalanceSufficient
                    ? AppColors.borderEmerald
                    : AppColors.roseRefund.withValues(alpha: 0.4),
                width: 1.2,
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
                        color: isBalanceSufficient ? AppColors.emerald : AppColors.roseRefund,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Order Amount:',
                      style: theme.textTheme.h4.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '৳${totalAmount.toStringAsFixed(0)}',
                      key: const Key('cart_total_escrow_text'),
                      style: theme.textTheme.h3.copyWith(
                        color: AppColors.emerald,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Insufficient Balance Deficit Alert Banner with 1-Tap bKash Top-up
          if (!isBalanceSufficient) ...[
            Container(
              key: const Key('insufficient_balance_alert'),
              padding: const EdgeInsets.all(14.0),
              decoration: BoxDecoration(
                color: AppColors.roseRefund.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.roseRefund.withValues(alpha: 0.5),
                  width: 1.2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(LucideIcons.alertTriangle, size: 18, color: AppColors.roseRefund),
                      const SizedBox(width: 8),
                      Text(
                        'Insufficient Available Balance',
                        style: theme.textTheme.large.copyWith(
                          color: AppColors.roseRefund,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'You need ৳${deficit.toStringAsFixed(0)} more in your available wallet to place this group order.',
                    style: theme.textTheme.small.copyWith(color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 12),
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
                          Text(
                            'Top-up ৳${deficit.toStringAsFixed(0)} via bKash',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          if (_checkoutError != null) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Text(
                _checkoutError!,
                style: const TextStyle(color: AppColors.roseRefund, fontSize: 13),
              ),
            ),
          ],

          // Proceed to Checkout Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ShadButton(
              key: const Key('proceed_to_checkout_btn'),
              enabled: totalAmount > 0,
              backgroundColor: AppColors.emerald,
              foregroundColor: Colors.white,
              onPressed: () => context.push(RoutePaths.checkout),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Proceed to Checkout',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '(৳${totalAmount.toStringAsFixed(0)})',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(width: 8),
                  const Icon(LucideIcons.arrowRight, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
