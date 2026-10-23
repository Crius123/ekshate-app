import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../domain/procurement_manifest.dart';
import 'procurement_controller.dart';

class ProcurementScreen extends ConsumerWidget {
  const ProcurementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ShadTheme.of(context);
    final selectedDate = ref.watch(selectedProcurementDateProvider);
    final manifestAsync = ref.watch(currentManifestStreamProvider);
    final controller = ref.read(procurementControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Morning Procurement', style: theme.textTheme.h4),
            Text(
              '4:00 AM Physical Purchasing Manifest',
              style: theme.textTheme.muted.copyWith(fontSize: 11),
            ),
          ],
        ),
        actions: [
          // 1-Tap CSV Export Action in AppBar
          manifestAsync.maybeWhen(
            data: (manifest) {
              if (manifest == null || manifest.items.isEmpty) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: IconButton(
                  key: const Key('appbar_csv_export_button'),
                  tooltip: 'Export CSV',
                  icon: const Icon(LucideIcons.fileSpreadsheet),
                  onPressed: () => _handleExportCsv(context, ref, manifest.csvPayload),
                ),
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Operations Morning Depot Banner
              _buildDepotBanner(context, theme),
              const SizedBox(height: 12),

              // Date Selection Chips
              _buildDateSelectorBar(context, theme, ref, selectedDate),
              const SizedBox(height: 16),

              manifestAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40.0),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (err, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text(
                      'Failed to load procurement manifest: $err',
                      style: theme.textTheme.p.copyWith(color: Colors.red),
                    ),
                  ),
                ),
                data: (manifest) {
                  if (manifest == null || manifest.items.isEmpty) {
                    return _buildEmptyState(context, theme, selectedDate);
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Morning Procurement Summary Cards
                      _buildSummaryCards(context, theme, manifest, controller),
                      const SizedBox(height: 16),

                      // Procurement Progress Checklist Bar
                      _buildProgressBar(context, theme, manifest),
                      const SizedBox(height: 16),

                      // Action Toolbar with 1-Tap CSV Export & Preview
                      _buildActionToolbar(context, theme, ref, manifest),
                      const SizedBox(height: 16),

                      // Section Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Wholesale Checklist', style: theme.textTheme.h4),
                          Text(
                            '${manifest.procuredItemsCount} / ${manifest.totalItemsCount} Procured',
                            style: theme.textTheme.muted.copyWith(fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Itemized Wholesale Checklist
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: manifest.items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final item = manifest.items[index];
                          return _buildChecklistItemCard(context, theme, item, controller);
                        },
                      ),
                      const SizedBox(height: 40),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDepotBanner(BuildContext context, ShadThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(LucideIcons.truck, size: 20, color: Color(0xFF38BDF8)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Karwan Bazar & Farm Depots',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFF0284C7)),
                      ),
                      child: const Text(
                        '4:00 AM RUN',
                        style: TextStyle(
                          color: Color(0xFF38BDF8),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Physical purchasing quotas aggregated from confirmed won buckets following 11:59 PM midnight settlement.',
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelectorBar(
    BuildContext context,
    ShadThemeData theme,
    WidgetRef ref,
    String selectedDate,
  ) {
    final today = getTodayDhakaDateString();
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final yesterdayStr =
        '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildDateChip(
            label: 'Today ($today)',
            isSelected: selectedDate == today,
            onTap: () => ref.read(selectedProcurementDateProvider.notifier).state = today,
            theme: theme,
          ),
          const SizedBox(width: 8),
          _buildDateChip(
            label: 'Yesterday ($yesterdayStr)',
            isSelected: selectedDate == yesterdayStr,
            onTap: () => ref.read(selectedProcurementDateProvider.notifier).state = yesterdayStr,
            theme: theme,
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            key: const Key('custom_date_picker_button'),
            icon: const Icon(LucideIcons.calendar, size: 14),
            label: Text(
              selectedDate != today && selectedDate != yesterdayStr
                  ? selectedDate
                  : 'Select Date',
              style: const TextStyle(fontSize: 12),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime(2025),
                lastDate: DateTime(2030),
              );
              if (picked != null) {
                final dateStr =
                    '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                ref.read(selectedProcurementDateProvider.notifier).state = dateStr;
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDateChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required ShadThemeData theme,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primary : theme.colorScheme.muted.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? theme.colorScheme.primary : theme.colorScheme.border.withValues(alpha: 0.5),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? theme.colorScheme.primaryForeground : theme.colorScheme.foreground,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCards(
    BuildContext context,
    ShadThemeData theme,
    ProcurementManifest manifest,
    ProcurementController controller,
  ) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                context: context,
                theme: theme,
                title: 'Total Volume',
                value: '${manifest.totalConfirmedVolume.toStringAsFixed(0)} kg',
                subtitle: '${manifest.totalBucketsCount} Confirmed Buckets',
                icon: LucideIcons.scale,
                iconColor: const Color(0xFF0284C7),
                iconBg: const Color(0xFFE0F2FE),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricCard(
                context: context,
                theme: theme,
                title: 'Est. Wholesale Budget',
                value: '৳ ${manifest.totalProcurementCost.toStringAsFixed(0)}',
                subtitle: 'Cash for Market Agents',
                icon: LucideIcons.banknote,
                iconColor: const Color(0xFF059669),
                iconBg: const Color(0xFFD1FAE5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                context: context,
                theme: theme,
                title: 'Distinct SKUs',
                value: '${manifest.totalItemsCount} Products',
                subtitle: 'Itemized Market Quotas',
                icon: LucideIcons.boxes,
                iconColor: const Color(0xFF7C3AED),
                iconBg: const Color(0xFFEDE9FE),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildStatusCard(context, theme, manifest, controller),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required BuildContext context,
    required ShadThemeData theme,
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.border.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: theme.textTheme.muted.copyWith(fontSize: 11)),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
                child: Icon(icon, size: 14, color: iconColor),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.h4.copyWith(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 2),
          Text(subtitle, style: theme.textTheme.muted.copyWith(fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildStatusCard(
    BuildContext context,
    ShadThemeData theme,
    ProcurementManifest manifest,
    ProcurementController controller,
  ) {
    Color badgeColor;
    Color badgeBg;
    switch (manifest.status) {
      case ManifestStatus.pendingProcurement:
        badgeColor = const Color(0xFFD97706);
        badgeBg = const Color(0xFFFEF3C7);
        break;
      case ManifestStatus.inProcurement:
        badgeColor = const Color(0xFF2563EB);
        badgeBg = const Color(0xFFDBEAFE);
        break;
      case ManifestStatus.procured:
        badgeColor = const Color(0xFF059669);
        badgeBg = const Color(0xFFD1FAE5);
        break;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.border.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Manifest Status', style: theme.textTheme.muted.copyWith(fontSize: 11)),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: badgeBg, shape: BoxShape.circle),
                child: Icon(LucideIcons.clock, size: 14, color: badgeColor),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
            ),
            child: Text(
              manifest.status.label,
              style: TextStyle(
                color: badgeColor,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap item checkboxes to update',
            style: theme.textTheme.muted.copyWith(fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(
    BuildContext context,
    ShadThemeData theme,
    ProcurementManifest manifest,
  ) {
    final ratio = manifest.completionRatio;
    final percent = (ratio * 100).toInt();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.border.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Purchasing Completion',
                style: theme.textTheme.small.copyWith(fontWeight: FontWeight.w600),
              ),
              Text(
                '$percent% Complete',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: manifest.isFullyProcured
                      ? const Color(0xFF059669)
                      : theme.colorScheme.foreground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              backgroundColor: theme.colorScheme.muted.withValues(alpha: 0.4),
              valueColor: AlwaysStoppedAnimation<Color>(
                manifest.isFullyProcured ? const Color(0xFF059669) : const Color(0xFF2563EB),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionToolbar(
    BuildContext context,
    ShadThemeData theme,
    WidgetRef ref,
    ProcurementManifest manifest,
  ) {
    return Row(
      children: [
        // 1-Tap CSV Export Button
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            key: const Key('export_csv_button'),
            icon: const Icon(LucideIcons.fileSpreadsheet, size: 16),
            label: const Text('1-Tap CSV Export', style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => _handleExportCsv(context, ref, manifest.csvPayload),
          ),
        ),
        const SizedBox(width: 8),
        // Preview CSV Button
        Expanded(
          flex: 1,
          child: OutlinedButton.icon(
            key: const Key('preview_csv_button'),
            icon: const Icon(LucideIcons.eye, size: 16),
            label: const Text('Preview'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => _showCsvPreviewDialog(context, theme, ref, manifest.csvPayload),
          ),
        ),
      ],
    );
  }

  Widget _buildChecklistItemCard(
    BuildContext context,
    ShadThemeData theme,
    ProcurementItem item,
    ProcurementController controller,
  ) {
    final isDone = item.isProcured;

    return Container(
      decoration: BoxDecoration(
        color: isDone
            ? const Color(0xFFF0FDF4)
            : theme.colorScheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDone
              ? const Color(0xFF86EFAC)
              : theme.colorScheme.border.withValues(alpha: 0.6),
          width: isDone ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Checkbox, Title & SKU
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Progress toggle checkbox
                InkWell(
                  key: Key('toggle_procured_${item.sku}'),
                  onTap: () {
                    controller.toggleItemStatus(item.sku, !isDone);
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: isDone ? const Color(0xFF059669) : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isDone ? const Color(0xFF059669) : const Color(0xFF94A3B8),
                        width: 2,
                      ),
                    ),
                    child: isDone
                        ? const Icon(LucideIcons.check, size: 18, color: Colors.white)
                        : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.productTitle,
                        style: theme.textTheme.small.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          decoration: isDone ? TextDecoration.lineThrough : null,
                          color: isDone ? const Color(0xFF15803D) : theme.colorScheme.foreground,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.muted.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              item.sku,
                              style: theme.textTheme.muted.copyWith(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              item.category,
                              style: const TextStyle(
                                color: Color(0xFF2563EB),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Status Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isDone ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isDone ? const Color(0xFF22C55E) : const Color(0xFFF59E0B),
                    ),
                  ),
                  child: Text(
                    isDone ? 'PROCURED' : 'PENDING',
                    style: TextStyle(
                      color: isDone ? const Color(0xFF15803D) : const Color(0xFFB45309),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 18),

            // Quotas & Wholesale Pricing Row
            Row(
              children: [
                Expanded(
                  child: _buildItemDetailBlock(
                    label: 'Total Volume',
                    value: '${item.totalVolume.toStringAsFixed(0)} ${item.unit}',
                    extra: '${item.confirmedBucketsCount} Won Buckets',
                    theme: theme,
                  ),
                ),
                Expanded(
                  child: _buildItemDetailBlock(
                    label: 'Est. Wholesale Cost',
                    value: '৳ ${item.estimatedUnitCost.toStringAsFixed(0)} / ${item.unit}',
                    extra: 'Budget: ৳ ${item.totalBudget.toStringAsFixed(0)}',
                    theme: theme,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Sourcing Depot & Packaging Breakdown
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDone
                    ? const Color(0xFFE2E8F0).withValues(alpha: 0.3)
                    : theme.colorScheme.muted.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(LucideIcons.mapPin, size: 12, color: Color(0xFFEF4444)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          item.targetMarket,
                          style: theme.textTheme.small.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(LucideIcons.packageCheck, size: 12, color: Color(0xFF0284C7)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Packaging Spec: ${item.packagingNotes}',
                          style: theme.textTheme.muted.copyWith(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemDetailBlock({
    required String label,
    required String value,
    required String extra,
    required ShadThemeData theme,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.muted.copyWith(fontSize: 10)),
        const SizedBox(height: 2),
        Text(value, style: theme.textTheme.small.copyWith(fontWeight: FontWeight.bold, fontSize: 13)),
        Text(extra, style: theme.textTheme.muted.copyWith(fontSize: 10)),
      ],
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    ShadThemeData theme,
    String selectedDate,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40.0, horizontal: 20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.muted.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(LucideIcons.clipboardList, size: 40, color: theme.colorScheme.mutedForeground),
            ),
            const SizedBox(height: 16),
            Text(
              'No Confirmed Buckets',
              style: theme.textTheme.h4,
            ),
            const SizedBox(height: 8),
            Text(
              'No batch buckets met MOQ for date $selectedDate.\nConfirmed won buckets following midnight settlement (11:59 PM) will be automatically compiled here for morning physical procurement.',
              textAlign: TextAlign.center,
              style: theme.textTheme.muted.copyWith(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  void _handleExportCsv(BuildContext context, WidgetRef ref, String csvPayload) async {
    final controller = ref.read(procurementControllerProvider.notifier);
    final success = await controller.exportCsvToClipboard(csvPayload);

    if (context.mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            key: Key('csv_export_snackbar'),
            content: Text('Procurement manifest CSV copied to clipboard! Standardized for Excel/Karwan Bazar agents.'),
            backgroundColor: Color(0xFF059669),
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to copy CSV to clipboard.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showCsvPreviewDialog(
    BuildContext context,
    ShadThemeData theme,
    WidgetRef ref,
    String csvPayload,
  ) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Standardized CSV Payload', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(LucideIcons.x, size: 18),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  csvPayload,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: Color(0xFFE2E8F0),
                  ),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
            ElevatedButton.icon(
              icon: const Icon(LucideIcons.copy, size: 14),
              label: const Text('Copy CSV'),
              onPressed: () {
                _handleExportCsv(context, ref, csvPayload);
                Navigator.of(ctx).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
