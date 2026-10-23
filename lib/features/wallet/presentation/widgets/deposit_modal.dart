import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../../domain/wallet_state.dart';
import '../wallet_controller.dart';
import 'bkash_checkout_dialog.dart';
import 'sslcommerz_checkout_dialog.dart';

class DepositModal extends ConsumerStatefulWidget {
  final DepositGateway? initialGateway;
  final double? initialAmount;

  const DepositModal({super.key, this.initialGateway, this.initialAmount});

  static Future<void> show(
    BuildContext context, {
    DepositGateway? initialGateway,
    double? initialAmount,
  }) {
    return showShadDialog(
      context: context,
      builder: (context) => DepositModal(
        initialGateway: initialGateway,
        initialAmount: initialAmount,
      ),
    );
  }

  @override
  ConsumerState<DepositModal> createState() => _DepositModalState();
}

class _DepositModalState extends ConsumerState<DepositModal> {
  late final TextEditingController _amountController;
  late DepositGateway _selectedGateway;
  String? _validationError;

  final List<double> _quickAmounts = [500, 1000, 2500, 5000];

  @override
  void initState() {
    super.initState();
    final initial = widget.initialAmount != null && widget.initialAmount! > 0
        ? widget.initialAmount!.ceil().toString()
        : '1000';
    _amountController = TextEditingController(text: initial);
    _selectedGateway = widget.initialGateway ?? DepositGateway.bkash;
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  double? get _parsedAmount => double.tryParse(_amountController.text.trim());

  void _validate() {
    final amount = _parsedAmount;
    setState(() {
      if (amount == null || amount <= 0) {
        _validationError = 'Please enter a valid amount';
      } else if (amount < 10) {
        _validationError = 'Minimum deposit amount is ৳10';
      } else if (amount > 100000) {
        _validationError = 'Maximum deposit amount is ৳100,000';
      } else {
        _validationError = null;
      }
    });
  }

  Future<void> _handleProceed() async {
    _validate();
    if (_validationError != null) return;

    final amount = _parsedAmount!;
    final controller = ref.read(depositControllerProvider.notifier);

    final session = await controller.startDepositSession(
      amount: amount,
      gateway: _selectedGateway,
    );

    if (!mounted || session == null) return;

    Navigator.of(context).pop(); // Close initial input modal

    if (_selectedGateway == DepositGateway.bkash) {
      BkashCheckoutDialog.show(context);
    } else {
      SslcommerzCheckoutDialog.show(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final depositState = ref.watch(depositControllerProvider);

    return ShadDialog(
      title: const Text('Deposit Funds'),
      description: const Text('Add balance via bKash Tokenized Checkout or SSLCommerz with zero transaction fee.'),
      actions: [
        ShadButton.outline(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ShadButton(
          onPressed: depositState.isLoading ? null : _handleProceed,
          child: depositState.isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Proceed'),
        ),
      ],
      child: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              // Amount Input
              Text('Deposit Amount (BDT)', style: theme.textTheme.small),
              const SizedBox(height: 6),
              ShadInput(
                controller: _amountController,
                keyboardType: TextInputType.number,
                placeholder: const Text('e.g. 1000'),
                leading: const Padding(
                  padding: EdgeInsets.only(left: 12.0, right: 6.0),
                  child: Text('৳', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                onChanged: (_) => _validate(),
              ),
              if (_validationError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    _validationError!,
                    style: theme.textTheme.small.copyWith(color: theme.colorScheme.destructive),
                  ),
                ),
              const SizedBox(height: 12),

              // Quick Preset Chips
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _quickAmounts.map((amt) {
                  final isSelected = _amountController.text == amt.toStringAsFixed(0);
                  return InkWell(
                    onTap: () {
                      _amountController.text = amt.toStringAsFixed(0);
                      _validate();
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? theme.colorScheme.primary.withValues(alpha: 0.15)
                            : theme.colorScheme.secondary.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isSelected ? theme.colorScheme.primary : Colors.transparent,
                        ),
                      ),
                      child: Text(
                        '+৳${amt.toStringAsFixed(0)}',
                        style: theme.textTheme.small.copyWith(
                          color: isSelected ? theme.colorScheme.primary : null,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),

              // Gateway Selection
              Text('Select Payment Gateway', style: theme.textTheme.small),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _selectedGateway = DepositGateway.bkash),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _selectedGateway == DepositGateway.bkash
                              ? const Color(0xFFE2136E).withValues(alpha: 0.12)
                              : theme.colorScheme.secondary.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _selectedGateway == DepositGateway.bkash
                                ? const Color(0xFFE2136E)
                                : Colors.white12,
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: Color(0xFFE2136E),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(LucideIcons.smartphone, color: Colors.white, size: 18),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'bKash Tokenized',
                              style: theme.textTheme.small.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Text('Instant PIN Flow', style: theme.textTheme.muted),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _selectedGateway = DepositGateway.sslcommerz),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _selectedGateway == DepositGateway.sslcommerz
                              ? theme.colorScheme.primary.withValues(alpha: 0.12)
                              : theme.colorScheme.secondary.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _selectedGateway == DepositGateway.sslcommerz
                                ? theme.colorScheme.primary
                                : Colors.white12,
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(LucideIcons.creditCard, color: Colors.white, size: 18),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'SSLCommerz',
                              style: theme.textTheme.small.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Text('Cards & Net Banking', style: theme.textTheme.muted),
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
      ),
    );
  }
}
