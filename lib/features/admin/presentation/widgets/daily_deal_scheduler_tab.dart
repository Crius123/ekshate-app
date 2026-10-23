import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../../domain/scheduled_deal_input.dart';
import '../admin_controller.dart';

class DailyDealSchedulerTab extends ConsumerStatefulWidget {
  const DailyDealSchedulerTab({super.key});

  @override
  ConsumerState<DailyDealSchedulerTab> createState() => _DailyDealSchedulerTabState();
}

class _DailyDealSchedulerTabState extends ConsumerState<DailyDealSchedulerTab> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _dateController;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _marketPriceController = TextEditingController();
  final TextEditingController _unitPriceController = TextEditingController();
  final TextEditingController _moqController = TextEditingController();
  final TextEditingController _imageUrlController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  String _selectedCategory = 'Vegetables & Greens';
  String _selectedUnit = 'kg';

  final List<String> _categories = [
    'Vegetables & Greens',
    'Fresh Meat & Poultry',
    'Staples & Grains',
    'Cooking Essentials',
    'Fresh Fruits',
  ];

  final List<String> _units = ['kg', 'liter', 'pack', 'crate', 'piece'];

  @override
  void initState() {
    super.initState();
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final tomorrowStr =
        '${tomorrow.year.toString().padLeft(4, '0')}-${tomorrow.month.toString().padLeft(2, '0')}-${tomorrow.day.toString().padLeft(2, '0')}';
    _dateController = TextEditingController(text: tomorrowStr);

    _marketPriceController.addListener(() => setState(() {}));
    _unitPriceController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _dateController.dispose();
    _titleController.dispose();
    _marketPriceController.dispose();
    _unitPriceController.dispose();
    _moqController.dispose();
    _imageUrlController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  double get _computedSavings {
    final market = double.tryParse(_marketPriceController.text) ?? 0.0;
    final unit = double.tryParse(_unitPriceController.text) ?? 0.0;
    if (market > 0 && unit > 0 && market > unit) {
      return market - unit;
    }
    return 0.0;
  }

  double get _computedDiscountPercent {
    final market = double.tryParse(_marketPriceController.text) ?? 0.0;
    final unit = double.tryParse(_unitPriceController.text) ?? 0.0;
    if (market > 0 && unit > 0 && market > unit) {
      return ((market - unit) / market) * 100;
    }
    return 0.0;
  }

  void _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    final marketPrice = double.tryParse(_marketPriceController.text) ?? 0.0;
    final unitPrice = double.tryParse(_unitPriceController.text) ?? 0.0;
    final moq = double.tryParse(_moqController.text) ?? 0.0;

    if (unitPrice >= marketPrice) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bulk discounted price must be lower than benchmark retail price.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final deal = ScheduledDealInput(
      date: _dateController.text.trim(),
      productTitle: _titleController.text.trim(),
      category: _selectedCategory,
      unit: _selectedUnit,
      marketPrice: marketPrice,
      unitPrice: unitPrice,
      moqThreshold: moq,
      imageUrl: _imageUrlController.text.trim().isNotEmpty
          ? _imageUrlController.text.trim()
          : 'https://cdn.ekshate.com/default-produce.jpg',
      description: _descriptionController.text.trim(),
    );

    final success = await ref.read(adminActionControllerProvider.notifier).scheduleDeal(deal);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully scheduled "${deal.productTitle}" with Bucket #1!'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );

      _titleController.clear();
      _marketPriceController.clear();
      _unitPriceController.clear();
      _moqController.clear();
      _imageUrlController.clear();
      _descriptionController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final actionState = ref.watch(adminActionControllerProvider);
    final savings = _computedSavings;
    final discount = _computedDiscountPercent;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Info Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF1E293B)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(LucideIcons.calendarPlus, color: Color(0xFF38BDF8), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Provision Daily Wholesale Listing', style: theme.textTheme.small.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(
                          'Schedule wholesale produce with MOQ targets and auto-initialized Bucket #1.',
                          style: theme.textTheme.muted.copyWith(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Target Campaign Date Field
            Text('Target Campaign Date (YYYY-MM-DD)', style: theme.textTheme.muted.copyWith(fontSize: 12)),
            const SizedBox(height: 6),
            TextFormField(
              key: const Key('deal_date_input'),
              controller: _dateController,
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF0F172A),
                hintText: '2026-10-24',
                prefixIcon: const Icon(LucideIcons.calendar, size: 16, color: Color(0xFF94A3B8)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF334155))),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Date is required' : null,
            ),
            const SizedBox(height: 14),

            // Product Title Field
            Text('Product Title', style: theme.textTheme.muted.copyWith(fontSize: 12)),
            const SizedBox(height: 6),
            TextFormField(
              key: const Key('deal_title_input'),
              controller: _titleController,
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF0F172A),
                hintText: 'e.g. Organic Sonali Chicken',
                prefixIcon: const Icon(LucideIcons.shoppingBag, size: 16, color: Color(0xFF94A3B8)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF334155))),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Product title is required' : null,
            ),
            const SizedBox(height: 14),

            // Category Selection Chips
            Text('Produce Category', style: theme.textTheme.muted.copyWith(fontSize: 12)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categories.map((cat) {
                final isSelected = cat == _selectedCategory;
                return ChoiceChip(
                  label: Text(cat, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : const Color(0xFF94A3B8))),
                  selected: isSelected,
                  selectedColor: const Color(0xFF10B981),
                  backgroundColor: const Color(0xFF0F172A),
                  onSelected: (val) {
                    if (val) setState(() => _selectedCategory = cat);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            // Unit Selection Chips
            Text('Measurement Unit', style: theme.textTheme.muted.copyWith(fontSize: 12)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: _units.map((unit) {
                final isSelected = unit == _selectedUnit;
                return ChoiceChip(
                  label: Text(unit, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : const Color(0xFF94A3B8))),
                  selected: isSelected,
                  selectedColor: const Color(0xFF0EA5E9),
                  backgroundColor: const Color(0xFF0F172A),
                  onSelected: (val) {
                    if (val) setState(() => _selectedUnit = unit);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            // Pricing Row: Market Price vs Bulk Price
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Retail Market Benchmark (৳)', style: theme.textTheme.muted.copyWith(fontSize: 12)),
                      const SizedBox(height: 6),
                      TextFormField(
                        key: const Key('deal_market_price_input'),
                        controller: _marketPriceController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFF0F172A),
                          hintText: '320',
                          prefixText: '৳ ',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF334155))),
                        ),
                        validator: (v) {
                          final num = double.tryParse(v ?? '');
                          if (num == null || num <= 0) return 'Invalid price';
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Bulk Discount Price (৳)', style: theme.textTheme.muted.copyWith(fontSize: 12)),
                      const SizedBox(height: 6),
                      TextFormField(
                        key: const Key('deal_unit_price_input'),
                        controller: _unitPriceController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFF0F172A),
                          hintText: '240',
                          prefixText: '৳ ',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF334155))),
                        ),
                        validator: (v) {
                          final num = double.tryParse(v ?? '');
                          if (num == null || num <= 0) return 'Invalid price';
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Dynamically Computed Savings Badge
            Container(
              key: const Key('savings_computation_badge'),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: discount > 0 ? const Color(0xFF10B981).withValues(alpha: 0.12) : const Color(0xFF334155).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: discount > 0 ? const Color(0xFF10B981).withValues(alpha: 0.3) : const Color(0xFF334155)),
              ),
              child: Row(
                children: [
                  Icon(LucideIcons.tag, size: 16, color: discount > 0 ? const Color(0xFF10B981) : const Color(0xFF94A3B8)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      discount > 0
                          ? '${discount.toStringAsFixed(1)}% OFF • Saves ৳${savings.toStringAsFixed(0)}/$_selectedUnit'
                          : 'Enter benchmark & bulk price to compute community savings percentage',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: discount > 0 ? FontWeight.bold : FontWeight.normal,
                        color: discount > 0 ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // MOQ Threshold Input
            Text('Minimum Order Quantity (MOQ Threshold in $_selectedUnit)', style: theme.textTheme.muted.copyWith(fontSize: 12)),
            const SizedBox(height: 6),
            TextFormField(
              key: const Key('deal_moq_input'),
              controller: _moqController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF0F172A),
                hintText: 'e.g. 50',
                suffixText: _selectedUnit,
                prefixIcon: const Icon(LucideIcons.layers, size: 16, color: Color(0xFF94A3B8)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF334155))),
              ),
              validator: (v) {
                final num = double.tryParse(v ?? '');
                if (num == null || num <= 0) return 'Invalid MOQ target';
                return null;
              },
            ),
            const SizedBox(height: 14),

            // Hero Image URL Field
            Text('Hero Image URL', style: theme.textTheme.muted.copyWith(fontSize: 12)),
            const SizedBox(height: 6),
            TextFormField(
              key: const Key('deal_image_input'),
              controller: _imageUrlController,
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF0F172A),
                hintText: 'https://cdn.ekshate.com/produce.jpg',
                prefixIcon: const Icon(LucideIcons.image, size: 16, color: Color(0xFF94A3B8)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF334155))),
              ),
            ),
            const SizedBox(height: 14),

            // Description Field (Optional)
            Text('Produce Description & Sourcing Specs (Optional)', style: theme.textTheme.muted.copyWith(fontSize: 12)),
            const SizedBox(height: 6),
            TextFormField(
              key: const Key('deal_description_input'),
              controller: _descriptionController,
              maxLines: 2,
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF0F172A),
                hintText: 'Directly sourced from Bogura farm cooperative...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF334155))),
              ),
            ),
            const SizedBox(height: 20),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                key: const Key('schedule_deal_submit_button'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: actionState.isLoading ? null : _submitForm,
                icon: actionState.isLoading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(LucideIcons.calendarCheck, size: 18),
                label: Text(
                  actionState.isLoading ? 'Provisioning...' : 'Schedule & Publish Wholesale Listing',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
