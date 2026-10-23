import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/config/theme/app_decorations.dart';
import '../../notifications/presentation/widgets/notification_bell_button.dart';
import '../domain/order_entity.dart';
import 'orders_controller.dart';

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ShadTheme.of(context);
    final selectedTab = ref.watch(orderFilterTabProvider);
    final filteredOrders = ref.watch(filteredOrdersProvider);
    final counts = ref.watch(orderCountsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('My Bulk Orders', style: theme.textTheme.h4),
        actions: [
          const NotificationBellButton(),
          IconButton(
            tooltip: 'Morning Procurement Manifest',
            icon: const Icon(LucideIcons.clipboardList),
            onPressed: () => context.go(RoutePaths.procurement),
          ),
        ],
      ),
      body: Column(
        children: [
          // Settlement & Dispatch Information Banner
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Container(
              padding: const EdgeInsets.all(14.0),
              decoration: AppDecorations.glassCard(
                surfaceColor: const Color(0xFF141926),
                borderColor: AppColors.amberEscrow.withValues(alpha: 0.35),
                borderRadius: 14,
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.amberEscrow.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(LucideIcons.clock, size: 18, color: AppColors.amberEscrow),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Midnight Settlement (11:59 PM BDT): Active batches pool volume toward MOQ. Confirmed orders are dispatched via Pathao, Steadfast, and RedX.',
                      style: theme.textTheme.small.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Filterable Segmented Tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.cardSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderSubtle, width: 1.2),
                ),
                child: Row(
                  children: [
                    _buildSegmentedTab(
                      context: context,
                      ref: ref,
                      tab: OrderFilterTab.activeEscrow,
                      label: 'Active Escrow (Pending)',
                      count: counts[OrderFilterTab.activeEscrow] ?? 0,
                      isSelected: selectedTab == OrderFilterTab.activeEscrow,
                      badgeColor: AppColors.amberEscrow,
                    ),
                    const SizedBox(width: 4),
                    _buildSegmentedTab(
                      context: context,
                      ref: ref,
                      tab: OrderFilterTab.confirmed,
                      label: 'Confirmed Deals',
                      count: counts[OrderFilterTab.confirmed] ?? 0,
                      isSelected: selectedTab == OrderFilterTab.confirmed,
                      badgeColor: AppColors.emerald,
                    ),
                    const SizedBox(width: 4),
                    _buildSegmentedTab(
                      context: context,
                      ref: ref,
                      tab: OrderFilterTab.dispatched,
                      label: 'Dispatched (In Transit)',
                      count: counts[OrderFilterTab.dispatched] ?? 0,
                      isSelected: selectedTab == OrderFilterTab.dispatched,
                      badgeColor: AppColors.skyCourier,
                    ),
                    const SizedBox(width: 4),
                    _buildSegmentedTab(
                      context: context,
                      ref: ref,
                      tab: OrderFilterTab.refunded,
                      label: 'Refunded Deals',
                      count: counts[OrderFilterTab.refunded] ?? 0,
                      isSelected: selectedTab == OrderFilterTab.refunded,
                      badgeColor: AppColors.roseRefund,
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Orders List / Empty State
          Expanded(
            child: filteredOrders.isEmpty
                ? _buildEmptyState(context, selectedTab)
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    itemCount: filteredOrders.length,
                    itemBuilder: (context, index) {
                      final order = filteredOrders[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14.0),
                        child: _OrderCard(order: order),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentedTab({
    required BuildContext context,
    required WidgetRef ref,
    required OrderFilterTab tab,
    required String label,
    required int count,
    required bool isSelected,
    required Color badgeColor,
  }) {
    final theme = ShadTheme.of(context);

    return InkWell(
      onTap: () {
        ref.read(orderFilterTabProvider.notifier).state = tab;
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.background : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? theme.colorScheme.foreground : theme.colorScheme.mutedForeground,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? badgeColor.withValues(alpha: 0.2) : theme.colorScheme.muted.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? badgeColor : theme.colorScheme.mutedForeground,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, OrderFilterTab tab) {
    final theme = ShadTheme.of(context);
    String title;
    String description;
    IconData icon;

    switch (tab) {
      case OrderFilterTab.activeEscrow:
        title = 'No Pending Escrow Orders';
        description = 'You have no orders currently waiting in open buckets.';
        icon = LucideIcons.hourglass;
        break;
      case OrderFilterTab.confirmed:
        title = 'No Confirmed Deals Yet';
        description = 'Orders for batches that achieve MOQ will appear here.';
        icon = LucideIcons.badgeCheck;
        break;
      case OrderFilterTab.dispatched:
        title = 'No Dispatched Orders';
        description = 'Orders dispatched via courier partners (Pathao, Steadfast, RedX) will appear here with live tracking.';
        icon = LucideIcons.truck;
        break;
      case OrderFilterTab.refunded:
        title = 'No Refunded Deals';
        description = 'Batches that did not reach MOQ before midnight will show here with restored escrow.';
        icon = LucideIcons.rotateCcw;
        break;
    }

    return Center(
      child: Container(
        margin: const EdgeInsets.all(24.0),
        padding: const EdgeInsets.all(32.0),
        decoration: AppDecorations.glassCard(
          surfaceColor: AppColors.cardSurface,
          borderColor: AppColors.borderSubtle,
          borderRadius: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.emerald.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: AppColors.emerald),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: theme.textTheme.h4.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: theme.textTheme.muted.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final OrderEntity order;

  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final dateFormat = DateFormat('d MMM yyyy, h:mm a');

    return Container(
      decoration: AppDecorations.glassCard(
        surfaceColor: AppColors.cardSurface,
        borderColor: AppColors.borderSubtle,
        borderRadius: 16,
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.productTitle,
                      style: theme.textTheme.large.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Order #${order.orderId} • ${dateFormat.format(order.createdAt)}',
                      style: theme.textTheme.muted.copyWith(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _buildStatusBadge(order),
            ],
          ),
          const SizedBox(height: 12),

          // Allocated Bucket Info with Live Tooltip
          Row(
            children: [
              ShadTooltip(
                builder: (context) => Container(
                  padding: const EdgeInsets.all(10),
                  constraints: const BoxConstraints(maxWidth: 280),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bucket #${order.bucketNumber} Live Status',
                        style: theme.textTheme.small.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(order.liveBucketTooltipText, style: theme.textTheme.muted),
                    ],
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.cardSurfaceElevated,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.boxes, size: 14, color: AppColors.emerald),
                      const SizedBox(width: 6),
                      Text(
                        'Allocated Bucket #${order.bucketNumber}',
                        style: theme.textTheme.small.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(LucideIcons.info, size: 13, color: AppColors.textMuted),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Quantity & Total Escrow / Amount
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.cardSurfaceElevated,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quantity Ordered',
                      style: theme.textTheme.muted.copyWith(fontSize: 11, color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${order.quantity % 1 == 0 ? order.quantity.toInt() : order.quantity} ${order.unit}',
                      style: theme.textTheme.small.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      order.isDispatched ? 'Total Paid' : 'Total Escrow Held',
                      style: theme.textTheme.muted.copyWith(fontSize: 11, color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '৳${order.totalAmount.toStringAsFixed(0)}',
                      style: theme.textTheme.small.copyWith(
                        fontWeight: FontWeight.bold,
                        color: order.isDispatched
                            ? AppColors.skyCourier
                            : (order.isConfirmed
                                ? AppColors.emerald
                                : (order.isPending ? AppColors.amberEscrow : AppColors.roseRefund)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Courier Dispatch & Consignment Tracking Card
          if (order.isDispatched) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.skyCourier.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.skyCourier.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildCourierPartnerPill(order.courierPartner, theme),
                      if (order.parcelWeightKg != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.cardSurfaceElevated,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Weight: ${order.parcelWeightKg} kg',
                            style: theme.textTheme.muted.copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(LucideIcons.barcode, size: 14, color: AppColors.textMuted),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Tracking: ${order.trackingCode ?? order.consignmentId ?? 'In Progress'}',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (order.trackingCode != null)
                        Builder(
                          builder: (ctx) => InkWell(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: order.trackingCode!));
                              ShadToaster.of(ctx).show(
                                ShadToast(
                                  title: const Text('Tracking Code Copied'),
                                  description: Text(order.trackingCode!),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(4),
                            child: Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(LucideIcons.copy, size: 13, color: AppColors.emerald),
                                  const SizedBox(width: 4),
                                  const Text(
                                    'Copy',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.emerald,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Delivery Destination
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(LucideIcons.mapPin, size: 14, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Delivery: ${order.deliveryAddress}',
                  style: theme.textTheme.muted.copyWith(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          _buildExplanatoryBanner(order, theme),
        ],
      ),
    );
  }

  Widget _buildCourierPartnerPill(String? partner, ShadThemeData theme) {
    final p = (partner ?? 'pathao').toLowerCase();
    String displayName;
    Color partnerColor;

    if (p == 'pathao') {
      displayName = 'Pathao Courier';
      partnerColor = const Color(0xFFEF4444);
    } else if (p == 'steadfast') {
      displayName = 'Steadfast Courier';
      partnerColor = const Color(0xFF059669);
    } else if (p == 'redx') {
      displayName = 'RedX Delivery';
      partnerColor = const Color(0xFFE11D48);
    } else {
      displayName = p.toUpperCase();
      partnerColor = const Color(0xFF0EA5E9);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: partnerColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: partnerColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.truck, size: 13, color: partnerColor),
          const SizedBox(width: 5),
          Text(
            displayName,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: partnerColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(OrderEntity order) {
    if (order.isDispatched) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF0EA5E9).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF0EA5E9).withValues(alpha: 0.4)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.truck, size: 12, color: Color(0xFF0EA5E9)),
            SizedBox(width: 4),
            Text(
              'DISPATCHED',
              style: TextStyle(
                color: Color(0xFF0EA5E9),
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    } else if (order.isConfirmed) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
        ),
        child: const Text(
          'CONFIRMED',
          style: TextStyle(
            color: Color(0xFF10B981),
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    } else if (order.isRefunded) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.4)),
        ),
        child: const Text(
          'REFUNDED',
          style: TextStyle(
            color: Color(0xFFEF4444),
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    } else {
      // Pending Escrow (amber)
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
        ),
        child: const Text(
          'PENDING ESCROW',
          style: TextStyle(
            color: Color(0xFFF59E0B),
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
  }

  Widget _buildExplanatoryBanner(OrderEntity order, ShadThemeData theme) {
    Color bannerColor;
    IconData bannerIcon;
    String explanation = order.statusExplanation;

    if (order.isDispatched) {
      bannerColor = const Color(0xFF0EA5E9);
      bannerIcon = LucideIcons.truck;
    } else if (order.isConfirmed) {
      bannerColor = const Color(0xFF10B981);
      bannerIcon = LucideIcons.checkCircle2;
    } else if (order.isRefunded) {
      bannerColor = const Color(0xFFEF4444);
      bannerIcon = LucideIcons.rotateCcw;
    } else {
      bannerColor = const Color(0xFFF59E0B);
      bannerIcon = LucideIcons.shieldAlert;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bannerColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: bannerColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(bannerIcon, size: 15, color: bannerColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              explanation,
              style: TextStyle(
                fontSize: 12,
                color: bannerColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
