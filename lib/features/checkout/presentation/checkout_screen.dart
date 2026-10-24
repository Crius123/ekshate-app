import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/theme/app_decorations.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../cart/domain/cart_item.dart';
import '../../cart/presentation/cart_controller.dart';
import '../../daily_sale/presentation/daily_sale_controller.dart';
import '../../wallet/presentation/wallet_controller.dart';
import '../../wallet/presentation/widgets/deposit_modal.dart';
import '../../wallet/domain/wallet_state.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../auth/domain/delivery_address.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final TextEditingController _couponController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  String? _appliedCouponCode;
  double _couponDiscount = 0.0;
  String? _couponError;

  bool _isCheckingOut = false;
  String? _checkoutError;

  @override
  void dispose() {
    _couponController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _applyCoupon(String code, double subtotal) {
    final cleanCode = code.trim().toUpperCase();
    setState(() {
      _couponError = null;
    });

    if (cleanCode.isEmpty) {
      setState(() {
        _couponError = 'Please enter a coupon code.';
      });
      return;
    }

    if (cleanCode == 'EKSHATE50') {
      if (subtotal < 200) {
        setState(() {
          _couponError = 'Minimum order value of ৳200 required for EKSHATE50.';
        });
        return;
      }
      setState(() {
        _appliedCouponCode = cleanCode;
        _couponDiscount = 50.0;
        _couponError = null;
      });
      HapticFeedback.lightImpact();
      ShadToaster.of(context).show(
        const ShadToast(
          title: Text('🎉 Coupon Applied!'),
          description: Text('৳50 discount applied to your batch order.'),
        ),
      );
    } else if (cleanCode == 'BATCH10') {
      final discount = (subtotal * 0.10).clamp(0.0, 200.0);
      setState(() {
        _appliedCouponCode = cleanCode;
        _couponDiscount = discount;
        _couponError = null;
      });
      HapticFeedback.lightImpact();
      ShadToaster.of(context).show(
        ShadToast(
          title: const Text('🎉 Coupon Applied!'),
          description: Text('10% (৳${discount.toStringAsFixed(0)}) discount applied.'),
        ),
      );
    } else if (cleanCode == 'FREESHIP') {
      setState(() {
        _appliedCouponCode = cleanCode;
        _couponDiscount = 50.0; // Standard delivery fee waiver
        _couponError = null;
      });
      HapticFeedback.lightImpact();
      ShadToaster.of(context).show(
        const ShadToast(
          title: Text('🎉 Free Delivery Applied!'),
          description: Text('Delivery fee waived for this order.'),
        ),
      );
    } else {
      setState(() {
        _couponError = 'Invalid coupon code. Try EKSHATE50, BATCH10, or FREESHIP.';
      });
      HapticFeedback.mediumImpact();
    }
  }

  void _removeCoupon() {
    setState(() {
      _appliedCouponCode = null;
      _couponDiscount = 0.0;
      _couponError = null;
      _couponController.clear();
    });
    HapticFeedback.lightImpact();
  }

  void _showAddressDialog({
    required BuildContext context,
    required String initialAddress,
    required String? initialPhone,
    required String? initialName,
  }) {
    final addressController = TextEditingController(text: initialAddress);
    final phoneController = TextEditingController(text: initialPhone ?? '');
    final nameController = TextEditingController(text: initialName ?? 'Customer');
    String? localError;

    showShadDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => ShadDialog(
          expandActionsWhenTiny: false,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.emerald.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.mapPin, size: 18, color: AppColors.emerald),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Delivery Address'),
              ),
            ],
          ),
          description: const Text(
            'Ensure your street address and contact phone are accurate for tomorrow morning courier fulfillment.',
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              const Text(
                'Recipient Name',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 4),
              ShadInput(
                controller: nameController,
                placeholder: const Text('Full Name'),
              ),
              const SizedBox(height: 12),
              const Text(
                'Contact Phone',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 4),
              ShadInput(
                controller: phoneController,
                placeholder: const Text('+8801XXXXXXXXX'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              const Text(
                'Street Address, House, Road & Area *',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 4),
              ShadInput(
                key: const Key('checkout_address_input'),
                controller: addressController,
                placeholder: const Text('e.g. House 12, Road 5, Block B, Dhanmondi, Dhaka'),
                maxLines: 3,
              ),
              if (localError != null) ...[
                const SizedBox(height: 8),
                Text(
                  localError!,
                  style: const TextStyle(color: AppColors.roseRefund, fontSize: 12),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ShadButton.outline(
                    onPressed: () => Navigator.of(dialogCtx).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ShadButton(
                    key: const Key('save_delivery_address_btn'),
                    backgroundColor: AppColors.emerald,
                    foregroundColor: Colors.white,
                    onPressed: () {
                      final address = addressController.text.trim();
                      final name = nameController.text.trim();
                      final phone = phoneController.text.trim();

                      if (address.isEmpty) {
                        setDialogState(() {
                          localError = 'Delivery street address is required.';
                        });
                        return;
                      }

                      final toaster = ShadToaster.of(context);
                      ref.read(authStateProvider.notifier).completeProfile(
                            displayName: name.isNotEmpty ? name : 'Customer',
                            address: DeliveryAddress(
                              addressLine: address,
                              area: '',
                              city: 'Dhaka',
                            ),
                          );

                      Navigator.of(dialogCtx).pop();
                      toaster.show(
                        const ShadToast(
                          title: Text('Address Saved'),
                          description: Text('Your delivery details have been updated.'),
                        ),
                      );
                    },
                    child: const Text('Save Address'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleConfirmOrder({
    required String deliveryAddress,
    required String? phone,
    required double finalPayable,
  }) async {
    setState(() {
      _isCheckingOut = true;
      _checkoutError = null;
    });

    try {
      HapticFeedback.mediumImpact();
      await ref.read(cartProvider.notifier).checkout(
            deliveryAddress: deliveryAddress,
            phone: phone,
            couponDiscount: _couponDiscount,
            couponCode: _appliedCouponCode,
          );

      if (!mounted) return;

      // Celebratory Toast
      ShadToaster.of(context).show(
        const ShadToast(
          title: Text('🎉 Batch Order Placed!'),
          description: Text(
            'Payment held safely in escrow. Allocation confirmed in active community group.',
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
            title: const Text('Order Confirmation Failed'),
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
    final theme = ShadTheme.of(context);
    final cartItems = ref.watch(cartProvider);
    final subtotal = ref.watch(cartTotalAmountProvider);
    final wallet = ref.watch(walletBalanceProvider);
    final authUser = ref.watch(authStateProvider).asData?.value;
    final dailyListings = ref.watch(dailyListingsProvider);

    final deliveryAddress = authUser?.deliveryAddress?.trim() ?? '';
    final hasValidAddress = deliveryAddress.isNotEmpty;

    // Delivery fee is standard ৳50 or free if subtotal > 1000 or FREESHIP coupon
    final standardDeliveryFee = subtotal >= 1000 ? 0.0 : 50.0;
    final effectiveDeliveryFee = _appliedCouponCode == 'FREESHIP' ? 0.0 : standardDeliveryFee;

    // Calculate total wholesale savings vs retail market price
    double totalWholesaleSavings = 0.0;
    for (final item in cartItems) {
      final listing = dailyListings.cast<dynamic>().firstWhere(
            (l) => l.id == item.listingId,
            orElse: () => null,
          );
      if (listing != null) {
        final diff = (listing.marketPrice - item.unitPrice).clamp(0.0, double.infinity);
        totalWholesaleSavings += diff * item.quantity;
      }
    }

    // Net payable calculation
    final grossPayable = subtotal + effectiveDeliveryFee;
    final netPayable = (grossPayable - _couponDiscount).clamp(0.0, double.infinity);
    final isBalanceSufficient = wallet.available >= netPayable;
    final deficit = (netPayable - wallet.available).clamp(0.0, double.infinity);

    final isDesktop = AdaptiveLayout.isDesktop(context);

    // Empty Cart Fallback
    if (cartItems.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Checkout'),
          leading: IconButton(
            icon: const Icon(LucideIcons.arrowLeft),
            onPressed: () => context.go(RoutePaths.dailySale),
          ),
        ),
        body: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24.0),
            padding: const EdgeInsets.all(32.0),
            constraints: const BoxConstraints(maxWidth: 480),
            decoration: AppDecorations.glassCard(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.emerald.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(LucideIcons.shoppingBag, size: 40, color: AppColors.emerald),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Your cart is empty',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Add products from today\'s wholesale drops before proceeding to checkout.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                ),
                const SizedBox(height: 24),
                ShadButton(
                  backgroundColor: AppColors.emerald,
                  foregroundColor: Colors.white,
                  onPressed: () => context.go(RoutePaths.dailySale),
                  child: const Text('Explore Deals'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Checkout', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.emerald.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.emerald.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.shieldCheck, size: 13, color: AppColors.emerald),
                    SizedBox(width: 4),
                    Text(
                      'Escrow Safe',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.emeraldDark),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go(RoutePaths.cart);
            }
          },
        ),
      ),
      bottomNavigationBar: !isDesktop
          ? _buildMobileStickyBottomBar(
              context: context,
              netPayable: netPayable,
              hasValidAddress: hasValidAddress,
              isBalanceSufficient: isBalanceSufficient,
              deliveryAddress: deliveryAddress,
              phone: authUser?.phoneNumber,
            )
          : null,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: isDesktop
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left Column: Address, Items, Delivery Time & Notes
                      Expanded(
                        flex: 6,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildAddressSection(context, authUser, hasValidAddress, deliveryAddress),
                            const SizedBox(height: 16),
                            _buildItemsSection(cartItems, dailyListings),
                            const SizedBox(height: 16),
                            _buildDeliveryTimeNotice(),
                            const SizedBox(height: 16),
                            _buildNotesSection(),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      // Right Column: Coupon, Payment & Summary
                      Expanded(
                        flex: 4,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildCouponSection(subtotal),
                            const SizedBox(height: 16),
                            _buildWalletEscrowSection(wallet, netPayable, isBalanceSufficient, deficit),
                            const SizedBox(height: 16),
                            _buildOrderSummarySection(
                              subtotal: subtotal,
                              wholesaleSavings: totalWholesaleSavings,
                              deliveryFee: effectiveDeliveryFee,
                              couponDiscount: _couponDiscount,
                              netPayable: netPayable,
                            ),
                            const SizedBox(height: 16),
                            _buildConfirmOrderButton(
                              netPayable: netPayable,
                              hasValidAddress: hasValidAddress,
                              isBalanceSufficient: isBalanceSufficient,
                              deliveryAddress: deliveryAddress,
                              phone: authUser?.phoneNumber,
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildAddressSection(context, authUser, hasValidAddress, deliveryAddress),
                      const SizedBox(height: 16),
                      _buildItemsSection(cartItems, dailyListings),
                      const SizedBox(height: 16),
                      _buildDeliveryTimeNotice(),
                      const SizedBox(height: 16),
                      _buildCouponSection(subtotal),
                      const SizedBox(height: 16),
                      _buildWalletEscrowSection(wallet, netPayable, isBalanceSufficient, deficit),
                      const SizedBox(height: 16),
                      _buildOrderSummarySection(
                        subtotal: subtotal,
                        wholesaleSavings: totalWholesaleSavings,
                        deliveryFee: effectiveDeliveryFee,
                        couponDiscount: _couponDiscount,
                        netPayable: netPayable,
                      ),
                      const SizedBox(height: 16),
                      _buildNotesSection(),
                      const SizedBox(height: 24),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 1. Delivery Address Confirmation Section
  // ---------------------------------------------------------------------------
  Widget _buildAddressSection(
    BuildContext context,
    dynamic authUser,
    bool hasValidAddress,
    String deliveryAddress,
  ) {
    if (!hasValidAddress) {
      return Container(
        key: const Key('checkout_no_address_banner'),
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.amberEscrow.withValues(alpha: 0.5), width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.amberEscrow.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(LucideIcons.alertCircle, color: AppColors.amberEscrow, size: 20),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Delivery Address Required',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.amberEscrow,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Please add your destination address to confirm your batch order.',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ShadButton(
                key: const Key('checkout_add_address_btn'),
                backgroundColor: AppColors.emerald,
                foregroundColor: Colors.white,
                onPressed: () => _showAddressDialog(
                  context: context,
                  initialAddress: '',
                  initialPhone: authUser?.phoneNumber,
                  initialName: authUser?.displayName,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(LucideIcons.plus, size: 15),
                    SizedBox(width: 6),
                    Text(
                      'Add Delivery Address',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: AppDecorations.glassCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.emerald.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(LucideIcons.mapPin, size: 16, color: AppColors.emerald),
                    ),
                    const SizedBox(width: 8),
                    const Flexible(
                      child: Text(
                        'Delivery Destination',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              ShadButton.outline(
                key: const Key('checkout_edit_address_btn'),
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                leading: const Icon(LucideIcons.pencil, size: 12),
                onPressed: () => _showAddressDialog(
                  context: context,
                  initialAddress: deliveryAddress,
                  initialPhone: authUser?.phoneNumber,
                  initialName: authUser?.displayName,
                ),
                child: const Text('Change', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.cardSurfaceElevated,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderSubtle, width: 1),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(LucideIcons.home, size: 18, color: AppColors.textMuted),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        children: [
                          Text(
                            authUser?.displayName ?? 'Customer',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                          ),
                          if (authUser?.phoneNumber != null)
                            Text(
                              authUser!.phoneNumber!,
                              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        deliveryAddress,
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.emerald.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Confirmed',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.emeraldDark),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. Order Items Review Section
  // ---------------------------------------------------------------------------
  Widget _buildItemsSection(List<CartItem> cartItems, List<dynamic> dailyListings) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: AppDecorations.glassCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.emerald.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(LucideIcons.shoppingBag, size: 16, color: AppColors.emerald),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Order Items (${cartItems.length})',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const Text(
                'Capacity Clamped',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.emerald),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: AppColors.borderSubtle, height: 1),
          const SizedBox(height: 12),
          ...cartItems.map((item) {
            final listing = dailyListings.cast<dynamic>().firstWhere(
                  (l) => l.id == item.listingId,
                  orElse: () => null,
                );

            return Container(
              key: Key('checkout_item_${item.listingId}'),
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
                  // Product Image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 56,
                      height: 56,
                      color: const Color(0xFFF1F5F9),
                      child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                          ? Image.network(
                              item.imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => const Center(
                                child: Icon(LucideIcons.shoppingBasket, size: 24, color: AppColors.emerald),
                              ),
                            )
                          : const Center(
                              child: Icon(LucideIcons.shoppingBasket, size: 24, color: AppColors.emerald),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Item Details & Controls
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                item.productTitle,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              key: Key('checkout_item_remove_${item.listingId}'),
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

                        // Unit Price & Market Benchmark Comparison
                        Row(
                          children: [
                            Text(
                              '৳${item.unitPrice.toStringAsFixed(0)} / ${item.unit}',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.emeraldDark),
                            ),
                            if (listing != null && listing.marketPrice > item.unitPrice) ...[
                              const SizedBox(width: 6),
                              Text(
                                '৳${listing.marketPrice.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  decoration: TextDecoration.lineThrough,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Quantity Stepper & Total
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: AppColors.cardSurface,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppColors.borderSubtle, width: 1),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  InkWell(
                                    key: Key('checkout_item_minus_${item.listingId}'),
                                    onTap: item.quantity > 1.0
                                        ? () {
                                            ref.read(cartProvider.notifier).updateQuantity(
                                                  item.listingId,
                                                  item.quantity - 1.0,
                                                );
                                          }
                                        : null,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                      child: Icon(
                                        LucideIcons.minus,
                                        size: 13,
                                        color: item.quantity > 1.0 ? AppColors.textPrimary : Colors.grey.shade400,
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    child: Text(
                                      '${item.quantity.toStringAsFixed(0)} ${item.unit}',
                                      key: Key('checkout_item_qty_${item.listingId}'),
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                    ),
                                  ),
                                  InkWell(
                                    key: Key('checkout_item_plus_${item.listingId}'),
                                    onTap: item.quantity < item.maxAllowedCapacity
                                        ? () {
                                            ref.read(cartProvider.notifier).updateQuantity(
                                                  item.listingId,
                                                  item.quantity + 1.0,
                                                );
                                          }
                                        : null,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                      child: Icon(
                                        LucideIcons.plus,
                                        size: 13,
                                        color: item.quantity < item.maxAllowedCapacity ? AppColors.emerald : Colors.grey.shade400,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '৳${item.totalAmount.toStringAsFixed(0)}',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.textPrimary),
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
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. Delivery Time & Midnight Settlement Notice
  // ---------------------------------------------------------------------------
  Widget _buildDeliveryTimeNotice() {
    return Container(
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.emerald.withValues(alpha: 0.3), width: 1.2),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.clock, size: 18, color: AppColors.emerald),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tomorrow Morning Fulfillment (9:00 AM – 1:00 PM)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.emeraldDark),
                ),
                SizedBox(height: 3),
                Text(
                  'Active batch buckets lock at 11:59 PM tonight. Sourced from wholesale primary markets at dawn and dispatched via Pathao, Steadfast, and RedX.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 4. Coupon Code Field & Promotional Suggestions
  // ---------------------------------------------------------------------------
  Widget _buildCouponSection(double subtotal) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: AppDecorations.glassCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.emerald.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(LucideIcons.tag, size: 16, color: AppColors.emerald),
              ),
              const SizedBox(width: 8),
              const Flexible(
                child: Text(
                  'Coupons & Savings',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (_appliedCouponCode != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.emerald.withValues(alpha: 0.4), width: 1),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(LucideIcons.sparkles, size: 16, color: AppColors.emerald),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            '$_appliedCouponCode applied (-৳${_couponDiscount.toStringAsFixed(0)})',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.emeraldDark),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    key: const Key('checkout_remove_coupon_btn'),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(LucideIcons.x, size: 16, color: AppColors.textMuted),
                    tooltip: 'Remove Coupon',
                    onPressed: _removeCoupon,
                  ),
                ],
              ),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: ShadInput(
                    key: const Key('checkout_coupon_input'),
                    controller: _couponController,
                    placeholder: const Text('Enter coupon code (e.g. EKSHATE50)'),
                  ),
                ),
                const SizedBox(width: 8),
                ShadButton(
                  key: const Key('checkout_apply_coupon_btn'),
                  backgroundColor: AppColors.emerald,
                  foregroundColor: Colors.white,
                  onPressed: () => _applyCoupon(_couponController.text, subtotal),
                  child: const Text('Apply'),
                ),
              ],
            ),
            if (_couponError != null) ...[
              const SizedBox(height: 6),
              Text(
                _couponError!,
                style: const TextStyle(color: AppColors.roseRefund, fontSize: 12),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _buildCouponSuggestionChip('EKSHATE50', 'Flat ৳50 off', subtotal),
                _buildCouponSuggestionChip('BATCH10', '10% off', subtotal),
                _buildCouponSuggestionChip('FREESHIP', 'Free delivery', subtotal),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCouponSuggestionChip(String code, String desc, double subtotal) {
    return InkWell(
      onTap: () {
        _couponController.text = code;
        _applyCoupon(code, subtotal);
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.cardSurfaceElevated,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.borderSubtle, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.badgePercent, size: 12, color: AppColors.emerald),
            const SizedBox(width: 4),
            Text(code, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.textPrimary)),
            const SizedBox(width: 4),
            Text('($desc)', style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 5. Escrow Payment & Wallet Balance
  // ---------------------------------------------------------------------------
  Widget _buildWalletEscrowSection(
    ({double available, double escrow, double total}) wallet,
    double netPayable,
    bool isBalanceSufficient,
    double deficit,
  ) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: AppDecorations.glassCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isBalanceSufficient
                      ? AppColors.emerald.withValues(alpha: 0.12)
                      : AppColors.amberEscrow.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  LucideIcons.wallet,
                  size: 16,
                  color: isBalanceSufficient ? AppColors.emerald : AppColors.amberEscrow,
                ),
              ),
              const SizedBox(width: 8),
              const Flexible(
                child: Text(
                  'Escrow Payment Rails',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
                      key: const Key('checkout_wallet_available_text'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isBalanceSufficient ? AppColors.emeraldDark : AppColors.amberEscrow,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Payment Status:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        isBalanceSufficient ? 'Funds Ready in Wallet' : 'Deficit: ৳${deficit.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isBalanceSufficient ? AppColors.emeraldDark : AppColors.roseRefund,
                        ),
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (!isBalanceSufficient) ...[
            const SizedBox(height: 12),
            Container(
              key: const Key('checkout_insufficient_balance_alert'),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.roseRefund.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.roseRefund.withValues(alpha: 0.4), width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(LucideIcons.alertTriangle, size: 16, color: AppColors.roseRefund),
                      const SizedBox(width: 6),
                      Text(
                        'Needs ৳${deficit.toStringAsFixed(0)} Top-up',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.roseRefund),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ShadButton(
                      key: const Key('checkout_topup_bkash_btn'),
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
                          const Icon(LucideIcons.zap, size: 15),
                          const SizedBox(width: 6),
                          Text('Top-up ৳${deficit.toStringAsFixed(0)} via bKash', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 6. Order Summary Section
  // ---------------------------------------------------------------------------
  Widget _buildOrderSummarySection({
    required double subtotal,
    required double wholesaleSavings,
    required double deliveryFee,
    required double couponDiscount,
    required double netPayable,
  }) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: AppDecorations.glassCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Order Summary',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Items Subtotal', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              Text('৳${subtotal.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            ],
          ),
          if (wholesaleSavings > 0) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Row(
                    children: [
                      Icon(LucideIcons.badgeCheck, size: 14, color: AppColors.emerald),
                      SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'Wholesale Savings',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.emeraldDark),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '-৳${wholesaleSavings.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.emeraldDark),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Delivery Fee', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              Text(
                deliveryFee == 0 ? 'FREE' : '৳${deliveryFee.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: deliveryFee == 0 ? AppColors.emeraldDark : AppColors.textPrimary,
                ),
              ),
            ],
          ),
          if (couponDiscount > 0) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Coupon Discount ($_appliedCouponCode)',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.emeraldDark),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '-৳${couponDiscount.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.emeraldDark),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          const Divider(color: AppColors.borderSubtle, height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Total Payable (Escrow)',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '৳${netPayable.toStringAsFixed(0)}',
                key: const Key('checkout_net_payable_text'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.emerald),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 7. Delivery Instructions / Notes
  // ---------------------------------------------------------------------------
  Widget _buildNotesSection() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: AppDecorations.glassCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.emerald.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(LucideIcons.fileText, size: 16, color: AppColors.emerald),
              ),
              const SizedBox(width: 8),
              const Flexible(
                child: Text(
                  'Delivery Instructions (Optional)',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ShadInput(
            controller: _notesController,
            placeholder: const Text('e.g. Leave with gate security, call before arrival...'),
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 8. Confirm Order Button
  // ---------------------------------------------------------------------------
  Widget _buildConfirmOrderButton({
    required double netPayable,
    required bool hasValidAddress,
    required bool isBalanceSufficient,
    required String deliveryAddress,
    required String? phone,
  }) {
    final canConfirm = hasValidAddress && isBalanceSufficient && !_isCheckingOut;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_checkoutError != null) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              _checkoutError!,
              style: const TextStyle(color: AppColors.roseRefund, fontSize: 13),
            ),
          ),
        ],
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ShadButton(
            key: const Key('confirm_escrow_funds_btn'),
            enabled: canConfirm,
            backgroundColor: AppColors.emerald,
            foregroundColor: Colors.white,
            leading: _isCheckingOut
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(LucideIcons.checkCheck, size: 16),
            onPressed: () => _handleConfirmOrder(
              deliveryAddress: deliveryAddress,
              phone: phone,
              finalPayable: netPayable,
            ),
            child: Text(
              _isCheckingOut
                  ? 'Holding Escrow Funds...'
                  : 'Confirm & Place Order (৳${netPayable.toStringAsFixed(0)})',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        if (!hasValidAddress) ...[
          const SizedBox(height: 6),
          const Center(
            child: Text(
              '⚠️ Please add a delivery address to place your order.',
              style: TextStyle(fontSize: 12, color: AppColors.amberEscrow, fontWeight: FontWeight.w600),
            ),
          ),
        ] else if (!isBalanceSufficient) ...[
          const SizedBox(height: 6),
          const Center(
            child: Text(
              '⚠️ Please top-up your wallet to confirm order escrow.',
              style: TextStyle(fontSize: 12, color: AppColors.roseRefund, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Mobile Sticky Bottom Bar
  // ---------------------------------------------------------------------------
  Widget _buildMobileStickyBottomBar({
    required BuildContext context,
    required double netPayable,
    required bool hasValidAddress,
    required bool isBalanceSufficient,
    required String deliveryAddress,
    required String? phone,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.cardSurface,
        border: Border(top: BorderSide(color: AppColors.borderSubtle, width: 1.2)),
        boxShadow: [
          BoxShadow(
            color: Color(0x0F0F172A),
            blurRadius: 10,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Total Escrow', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                Text(
                  '৳${netPayable.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.emerald),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ShadButton(
                key: const Key('confirm_escrow_funds_btn'),
                enabled: hasValidAddress && isBalanceSufficient && !_isCheckingOut,
                backgroundColor: AppColors.emerald,
                foregroundColor: Colors.white,
                onPressed: () => _handleConfirmOrder(
                  deliveryAddress: deliveryAddress,
                  phone: phone,
                  finalPayable: netPayable,
                ),
                child: _isCheckingOut
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text(
                        'Place Order',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
