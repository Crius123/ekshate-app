import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../wallet_controller.dart';

class SslcommerzCheckoutDialog extends ConsumerStatefulWidget {
  const SslcommerzCheckoutDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const SslcommerzCheckoutDialog(),
    );
  }

  @override
  ConsumerState<SslcommerzCheckoutDialog> createState() => _SslcommerzCheckoutDialogState();
}

class _SslcommerzCheckoutDialogState extends ConsumerState<SslcommerzCheckoutDialog> {
  String _selectedPaymentMethod = 'cards';

  void _copyTrxId(BuildContext context, String trxId) {
    Clipboard.setData(ClipboardData(text: trxId));
    ShadToaster.of(context).show(
      ShadToast(
        title: const Text('Transaction ID Copied'),
        description: Text(trxId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final depositState = ref.watch(depositControllerProvider);
    final session = depositState.session;
    final isVerifying = depositState.status == DepositFlowStatus.verifying;
    final isCompleted = depositState.status == DepositFlowStatus.completed;

    if (session == null) {
      return const SizedBox.shrink();
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            // SSLCommerz Branded Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: const Color(0xFF1B365D),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(LucideIcons.creditCard, color: Colors.white, size: 18),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'SSLCommerz Gateway',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                'Secure Hosted Session (v4.0)',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isVerifying && !isCompleted)
                    IconButton(
                      icon: const Icon(LucideIcons.x, color: Colors.white70, size: 18),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                ],
              ),
            ),

            // Dialog Body
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Session Info Card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B365D).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF1B365D).withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Ekshate Community Bulk Buy',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              Text(
                                'TranID: ${session.paymentId}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11, color: Colors.white60),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '৳${session.amount.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF38BDF8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (isCompleted) ...[
                    // Success View
                    Center(
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(LucideIcons.check, color: Colors.white, size: 32),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Payment & IPN Verified!',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '৳${session.amount.toStringAsFixed(0)} credited to Available Balance',
                            style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 14),
                          // Val ID with Copy
                          InkWell(
                            onTap: () => _copyTrxId(context, depositState.transaction?.trxId ?? session.gatewayTrxId),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white10,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'val_id: ${depositState.transaction?.trxId ?? session.gatewayTrxId}',
                                    style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(LucideIcons.copy, size: 14, color: Colors.white70),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          ShadButton(
                            width: double.infinity,
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Back to Wallet'),
                          ),
                        ],
                      ),
                    ),
                  ] else if (isVerifying) ...[
                    // Verification / Polling View
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24.0),
                        child: Column(
                          children: [
                            const SizedBox(
                              width: 48,
                              height: 48,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                color: Color(0xFF38BDF8),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              depositState.statusMessage ?? 'Simulating IPN Server-to-Server Callback...',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Querying validationServerAPI.php and executing atomic ledger credit...',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, color: Colors.white60),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    // Method Selection & Gateway Redirect
                    const Text(
                      'Select Payment Method',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _buildMethodPill('cards', 'Debit / Credit Card', LucideIcons.creditCard),
                        const SizedBox(width: 8),
                        _buildMethodPill('banking', 'Net Banking', LucideIcons.landmark),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Redirect notice
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(LucideIcons.link, size: 14, color: Color(0xFF38BDF8)),
                              SizedBox(width: 6),
                              Text(
                                'Gateway Redirect Session URL:',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            session.redirectUrl,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, color: Colors.white54, fontFamily: 'monospace'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: ShadButton.outline(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ShadButton(
                            backgroundColor: const Color(0xFF1B365D),
                            onPressed: () async {
                              await ref
                                  .read(depositControllerProvider.notifier)
                                  .confirmAndPollPayment();
                            },
                            child: const Text('Confirm'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ));
  }

  Widget _buildMethodPill(String id, String label, IconData icon) {
    final isSelected = _selectedPaymentMethod == id;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedPaymentMethod = id),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF1B365D).withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? const Color(0xFF38BDF8) : Colors.white12,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isSelected ? const Color(0xFF38BDF8) : Colors.white70),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? Colors.white : Colors.white70,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
