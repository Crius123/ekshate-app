import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../wallet_controller.dart';

class BkashCheckoutDialog extends ConsumerStatefulWidget {
  const BkashCheckoutDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const BkashCheckoutDialog(),
    );
  }

  @override
  ConsumerState<BkashCheckoutDialog> createState() => _BkashCheckoutDialogState();
}

class _BkashCheckoutDialogState extends ConsumerState<BkashCheckoutDialog> {
  final _pinController = TextEditingController(text: '12345');
  bool _pinVisible = false;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

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
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            // bKash Branded Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: const Color(0xFFE2136E),
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
                          child: const Icon(LucideIcons.smartphone, color: Colors.white, size: 18),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'bKash Tokenized',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                'Merchant Checkout (v1.2.0)',
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
                  // Merchant & Amount Row
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2136E).withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2136E).withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Ekshate Bulk Buying',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              Text(
                                'Invoice: ${session.paymentId}',
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
                            color: Color(0xFFE2136E),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

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
                            'Deposit Successful!',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '৳${session.amount.toStringAsFixed(0)} credited to Available Balance',
                            style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 14),
                          // TrxID with Copy Button
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
                                    'TrxID: ${depositState.transaction?.trxId ?? session.gatewayTrxId}',
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
                                color: Color(0xFFE2136E),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              depositState.statusMessage ?? 'Verifying with bKash API...',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Polling gateway transaction status and writing write-once ledger record...',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, color: Colors.white60),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    // Input PIN View
                    const Text(
                      'Enter bKash Account PIN',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _pinController,
                      obscureText: !_pinVisible,
                      keyboardType: TextInputType.number,
                      maxLength: 5,
                      decoration: InputDecoration(
                        hintText: '5-digit PIN',
                        counterText: '',
                        prefixIcon: const Icon(LucideIcons.lock, size: 18),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _pinVisible ? LucideIcons.eyeOff : LucideIcons.eye,
                            size: 18,
                          ),
                          onPressed: () => setState(() => _pinVisible = !_pinVisible),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Row(
                      children: [
                        Icon(LucideIcons.shieldCheck, size: 14, color: Color(0xFF10B981)),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Secured by 256-bit Tokenized Checkout API',
                            style: TextStyle(fontSize: 11, color: Colors.white60),
                          ),
                        ),
                      ],
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
                            backgroundColor: const Color(0xFFE2136E),
                            onPressed: () async {
                              await ref
                                  .read(depositControllerProvider.notifier)
                                  .confirmAndPollPayment(pin: _pinController.text);
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
}
