import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:ekshate_app/core/config/theme/app_decorations.dart';
import 'package:ekshate_app/core/router/route_paths.dart';
import 'package:ekshate_app/core/errors/app_exception.dart';
import 'package:ekshate_app/features/cart/presentation/cart_controller.dart';
import 'package:ekshate_app/features/wallet/presentation/wallet_controller.dart';
import 'package:ekshate_app/features/auth/presentation/auth_controller.dart';

/// Web slide-over sheet for reviewing batch-reserved items and confirming escrow.
class CartSheet extends StatelessWidget {
  const CartSheet({super.key});

  /// Opens the cart sheet from the right edge on web/desktop viewports.
  static Future<void> show(BuildContext context) {
    return showShadSheet<void>(
      context: context,
      side: ShadSheetSide.right,
      builder: (sheetContext) => const CartSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ShadSheet(
      constraints: const BoxConstraints(maxWidth: 460),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: AppDecorations.emeraldButtonGradient,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(LucideIcons.shoppingBag, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 10),
              const Text(
                'Batch Order Cart',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
      description: const Text(
        'Reserved bulk items awaiting midnight settlement.',
        style: TextStyle(fontSize: 12, color: AppColors.textMuted),
      ),
      child: const Material(
        color: Colors.transparent,
        child: _CartSheetContent(),
      ),
    );
  }
}

class _CartSheetContent extends ConsumerStatefulWidget {
  const _CartSheetContent();

  @override
  ConsumerState<_CartSheetContent> createState() => _CartSheetContentState();
}

class _CartSheetContentState extends ConsumerState<_CartSheetContent> {
  bool _isCheckingOut = false;

  Future<void> _handleCheckout(String deliveryAddress, String? phone) async {
    setState(() {
      _isCheckingOut = true;
    });

    try {
      HapticFeedback.mediumImpact();
      await ref.read(cartProvider.notifier).checkout(
            deliveryAddress: deliveryAddress,
            phone: phone,
          );

      if (!mounted) return;

      // Close the sheet
      Navigator.of(context).pop();

      // Celebratory Toast
      ShadToaster.of(context).show(
        const ShadToast(
          title: Text('🎉 Batch Order Placed!'),
          description: Text(
            'Payment held safely. Allocation confirmed in active community group.',
          ),
        ),
      );

      // Redirect to Orders
      context.go(RoutePaths.orders);
    } on InsufficientWalletBalanceException catch (e) {
      HapticFeedback.heavyImpact();
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

  @override
  Widget build(BuildContext context) {
    final cartItems = ref.watch(cartProvider);
    final totalAmount = ref.watch(cartTotalAmountProvider);
    final wallet = ref.watch(walletBalanceProvider);
    final authUser = ref.watch(authStateProvider).asData?.value;

    final deliveryAddress = authUser?.deliveryAddress?.trim() ?? '';
    final hasValidAddress = deliveryAddress.isNotEmpty;
    final isBalanceSufficient = wallet.available >= totalAmount;

    if (cartItems.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final mediaQuery = MediaQuery.sizeOf(context);
          // Account for sheet padding (~48), title + description (~80)
          final availableHeight = (mediaQuery.height - 140).clamp(320.0, double.infinity);

          return SizedBox(
            height: availableHeight,
            child: Center(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
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
                        child: const Icon(
                          LucideIcons.shoppingBag,
                          size: 44,
                          color: AppColors.emerald,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Your batch cart is empty',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Select items from today\'s active campaign wholesale drops',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                      ),
                      const SizedBox(height: 22),
                      ShadButton(
                        backgroundColor: AppColors.emerald,
                        foregroundColor: Colors.white,
                        onPressed: () {
                          Navigator.of(context).pop();
                          context.go(RoutePaths.dailySale);
                        },
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.sparkles, size: 15),
                            SizedBox(width: 8),
                            Text('Explore Deals', style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Items List with Product Image and Quantity Selector
          ...cartItems.map((item) {
            return Container(
              key: Key('cart_sheet_item_${item.listingId}'),
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.cardSurfaceElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderSubtle, width: 1),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product Image on the left-hand side
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 64,
                      height: 64,
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
                                    size: 24,
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
                                  size: 24,
                                  color: AppColors.emerald,
                                ),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Product Details & Quantity Adjuster
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title & Remove Button
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                item.productTitle,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            IconButton(
                              key: Key('cart_sheet_remove_${item.listingId}'),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              icon: const Icon(LucideIcons.trash2, size: 16, color: Color(0xFFEF4444)),
                              tooltip: 'Remove',
                              onPressed: () {
                                ref.read(cartProvider.notifier).removeItem(item.listingId);
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),

                        // Unit Price & Total Price
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '৳${item.unitPrice.toStringAsFixed(0)} / ${item.unit}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                            Text(
                              '৳${item.totalAmount.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: AppColors.emeraldDark,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Quantity Selector Stepper inside Cart Sheet
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Qty (${item.unit}):',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                color: AppColors.cardSurface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.borderSubtle, width: 1),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  InkWell(
                                    key: Key('cart_sheet_minus_${item.listingId}'),
                                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                                    onTap: item.quantity > 1.0
                                        ? () {
                                            ref.read(cartProvider.notifier).updateQuantity(
                                                  item.listingId,
                                                  item.quantity - 1.0,
                                                );
                                          }
                                        : null,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                      child: Icon(
                                        LucideIcons.minus,
                                        size: 14,
                                        color: item.quantity > 1.0
                                            ? AppColors.textPrimary
                                            : Colors.grey.shade400,
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    child: Text(
                                      '${item.quantity.toStringAsFixed(0)}',
                                      key: Key('cart_sheet_qty_${item.listingId}'),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  InkWell(
                                    key: Key('cart_sheet_plus_${item.listingId}'),
                                    borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                                    onTap: item.quantity < item.maxAllowedCapacity
                                        ? () {
                                            ref.read(cartProvider.notifier).updateQuantity(
                                                  item.listingId,
                                                  item.quantity + 1.0,
                                                );
                                          }
                                        : null,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                      child: Icon(
                                        LucideIcons.plus,
                                        size: 14,
                                        color: item.quantity < item.maxAllowedCapacity
                                            ? AppColors.emerald
                                            : Colors.grey.shade400,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 12),
          const Divider(color: AppColors.borderSubtle, height: 1),
          const SizedBox(height: 12),

          // Total & Available Wallet Row
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isBalanceSufficient ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isBalanceSufficient
                    ? AppColors.emerald.withValues(alpha: 0.3)
                    : AppColors.amberEscrow.withValues(alpha: 0.35),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Available Balance:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    Text(
                      '৳${wallet.available.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isBalanceSufficient ? AppColors.emeraldDark : AppColors.amberEscrow,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Order Subtotal:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    Text(
                      '৳${totalAmount.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Proceed to Checkout Button
          SizedBox(
            width: double.infinity,
            child: ShadButton(
              key: const Key('proceed_to_checkout_btn'),
              enabled: cartItems.isNotEmpty,
              backgroundColor: AppColors.emerald,
              foregroundColor: Colors.white,
              onPressed: () {
                Navigator.of(context).pop();
                context.push(RoutePaths.checkout);
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Proceed to Checkout',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '(৳${totalAmount.toStringAsFixed(0)})',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(width: 6),
                  const Icon(LucideIcons.arrowRight, size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
