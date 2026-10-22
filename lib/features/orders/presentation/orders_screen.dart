import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'orders_controller.dart';

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ShadTheme.of(context);
    final orders = ref.watch(ordersListProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('My Bulk Orders', style: theme.textTheme.h4),
      ),
      body: orders.isEmpty
          ? Center(
              child: Text('No orders placed yet', style: theme.textTheme.muted),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final order = orders[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: ShadCard(
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(order.productTitle, style: theme.textTheme.large),
                        _buildStatusBadge(order.status),
                      ],
                    ),
                    description: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 6),
                        Text(
                          'Order #${order.orderId} • Allocated to Bucket #${order.bucketNumber}',
                          style: theme.textTheme.muted,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${order.quantity.toStringAsFixed(0)} ${order.unit} • Total: ৳${order.totalAmount.toStringAsFixed(0)}',
                          style: theme.textTheme.small.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text('Delivery: ${order.deliveryAddress}', style: theme.textTheme.muted),
                      ],
                    ),
                    footer: Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        order.isPending
                            ? '⏳ Held in Escrow: Waiting for Bucket #${order.bucketNumber} to meet MOQ'
                            : (order.isConfirmed
                                ? '✅ Confirmed: Guaranteed fulfillment at midnight'
                                : '🔄 Refunded: Escrow returned to your wallet balance'),
                        style: theme.textTheme.small.copyWith(
                          color: order.isConfirmed
                              ? const Color(0xFF10B981)
                              : (order.isPending ? const Color(0xFFF59E0B) : Colors.redAccent),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildStatusBadge(String status) {
    switch (status) {
      case 'confirmed':
        return const ShadBadge(child: Text('CONFIRMED'));
      case 'refunded':
        return const ShadBadge.destructive(child: Text('REFUNDED'));
      case 'pending_bucket':
      default:
        return const ShadBadge.secondary(child: Text('PENDING ESCROW'));
    }
  }
}
