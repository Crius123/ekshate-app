import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../../domain/withdrawal_request.dart';
import '../admin_controller.dart';

class WithdrawalPayoutsTab extends ConsumerWidget {
  const WithdrawalPayoutsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ShadTheme.of(context);
    final selectedFilter = ref.watch(withdrawalFilterProvider);
    final withdrawalsAsync = ref.watch(withdrawalRequestsProvider);
    final actionState = ref.watch(adminActionControllerProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter Row
          _buildFilterChips(context, ref, selectedFilter),
          const SizedBox(height: 16),

          withdrawalsAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(40.0),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (err, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text('Failed to load withdrawal requests: $err', style: const TextStyle(color: Colors.red)),
              ),
            ),
            data: (requests) {
              if (requests.isEmpty) {
                return _buildEmptyWithdrawalsCard(theme, selectedFilter);
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: requests.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final req = requests[index];
                  return _buildWithdrawalCard(context, theme, ref, req, actionState);
                },
              );
            },
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildFilterChips(BuildContext context, WidgetRef ref, String currentFilter) {
    final filters = ['pending', 'approved', 'rejected', 'all'];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final isSelected = currentFilter.toLowerCase() == f;
          final label = f[0].toUpperCase() + f.substring(1);

          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              key: Key('filter_chip_$f'),
              label: Text(label),
              selected: isSelected,
              selectedColor: const Color(0xFF10B981),
              backgroundColor: const Color(0xFF0F172A),
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              onSelected: (val) {
                if (val) {
                  ref.read(withdrawalFilterProvider.notifier).state = f;
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildWithdrawalCard(
    BuildContext context,
    ShadThemeData theme,
    WidgetRef ref,
    WithdrawalRequest request,
    AdminActionState actionState,
  ) {
    Color statusColor;
    switch (request.status) {
      case 'approved':
        statusColor = const Color(0xFF10B981); // Emerald
        break;
      case 'rejected':
        statusColor = const Color(0xFFEF4444); // Red
        break;
      default:
        statusColor = const Color(0xFFF59E0B); // Amber
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      request.payoutMethod == 'bank' ? LucideIcons.building2 : LucideIcons.smartphone,
                      size: 18,
                      color: const Color(0xFF38BDF8),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.formattedAmount,
                        style: theme.textTheme.h4.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        request.payoutMethodLabel,
                        style: theme.textTheme.muted.copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  request.status.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFF1E293B)),
          const SizedBox(height: 10),

          // Customer Account Details
          Row(
            children: [
              const Icon(LucideIcons.user, size: 14, color: Color(0xFF94A3B8)),
              const SizedBox(width: 6),
              Text(
                'Customer: ${request.accountHolderName ?? request.userId}',
                style: theme.textTheme.small.copyWith(fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(LucideIcons.creditCard, size: 14, color: Color(0xFF94A3B8)),
              const SizedBox(width: 6),
              Text(
                'Account / Phone: ${request.accountNumber}',
                style: theme.textTheme.muted.copyWith(fontSize: 12),
              ),
            ],
          ),

          if (request.rejectionReason != null && request.rejectionReason!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.alertCircle, size: 14, color: Colors.red),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Rejection Reason: ${request.rejectionReason}',
                      style: const TextStyle(color: Colors.red, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (request.trxId != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(LucideIcons.receipt, size: 14, color: Color(0xFF10B981)),
                const SizedBox(width: 6),
                Text(
                  'Ledger TrxID: ${request.trxId}',
                  style: const TextStyle(color: Color(0xFF10B981), fontSize: 11, fontFamily: 'monospace'),
                ),
              ],
            ),
          ],

          // Action Buttons if pending
          if (request.isPending) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    key: Key('approve_button_${request.id}'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: actionState.isLoading ? null : () => _confirmAndApprove(context, ref, request),
                    icon: const Icon(LucideIcons.check, size: 16),
                    label: const Text('Approve & Payout', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    key: Key('reject_button_${request.id}'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: actionState.isLoading ? null : () => _showRejectDialog(context, ref, request),
                    icon: const Icon(LucideIcons.x, size: 16),
                    label: const Text('Reject with Reason', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyWithdrawalsCard(ShadThemeData theme, String filter) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Center(
        child: Column(
          children: [
            const Icon(LucideIcons.inbox, size: 40, color: Color(0xFF64748B)),
            const SizedBox(height: 10),
            Text(
              'No ${filter.toUpperCase()} Withdrawal Requests',
              style: theme.textTheme.small.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Customer funds withdrawal requests will appear here for review and settlement.',
              textAlign: TextAlign.center,
              style: theme.textTheme.muted.copyWith(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmAndApprove(BuildContext context, WidgetRef ref, WithdrawalRequest request) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve Withdrawal & Disburse'),
        content: Text(
          'Approve withdrawal of ${request.formattedAmount} to ${request.payoutMethodLabel} (${request.accountNumber})?\n\n'
          'This will atomically debit the customer available wallet balance and record an immutable ledger entry (type: withdrawal_payout).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            key: const Key('confirm_approve_payout_button'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            onPressed: () async {
              final messenger = ScaffoldMessenger.maybeOf(context);
              Navigator.of(ctx).pop();
              final success = await ref.read(adminActionControllerProvider.notifier).reviewWithdrawal(
                    requestId: request.id,
                    action: 'approve',
                  );
              if (success) {
                messenger?.showSnackBar(
                  SnackBar(
                    content: Text('Payout for ${request.formattedAmount} approved and ledger recorded!'),
                    backgroundColor: const Color(0xFF10B981),
                  ),
                );
              }
            },
            child: const Text('Confirm & Payout'),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(BuildContext context, WidgetRef ref, WithdrawalRequest request) {
    final reasonController = TextEditingController(text: 'Account details mismatch. Please re-enter your wallet number.');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Withdrawal Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Rejecting request for ${request.formattedAmount}. Please provide a clear explanation to the customer:'),
            const SizedBox(height: 12),
            TextField(
              key: const Key('rejection_reason_input'),
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                filled: true,
                border: OutlineInputBorder(),
                hintText: 'Enter reason for rejection...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            key: const Key('confirm_reject_button'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) return;

              final messenger = ScaffoldMessenger.maybeOf(context);
              Navigator.of(ctx).pop();
              final success = await ref.read(adminActionControllerProvider.notifier).reviewWithdrawal(
                    requestId: request.id,
                    action: 'reject',
                    rejectionReason: reason,
                  );
              if (success) {
                messenger?.showSnackBar(
                  const SnackBar(
                    content: Text('Withdrawal request rejected.'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            },
            child: const Text('Reject Request'),
          ),
        ],
      ),
    );
  }
}
