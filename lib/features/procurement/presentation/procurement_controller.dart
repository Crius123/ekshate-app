import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/procurement_repository.dart';
import '../domain/procurement_manifest.dart';

/// Helper to get current calendar date string in YYYY-MM-DD
String getTodayDhakaDateString() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}

/// Provider holding the selected calendar date string for the procurement manifest
final selectedProcurementDateProvider = StateProvider<String>((ref) {
  return getTodayDhakaDateString();
});

/// Stream provider watching the procurement manifest for the active selected date
final currentManifestStreamProvider = StreamProvider<ProcurementManifest?>((ref) {
  final repo = ref.watch(procurementRepositoryProvider);
  final date = ref.watch(selectedProcurementDateProvider);
  return repo.watchManifest(date);
});

/// Notifier managing procurement manifest actions and interactions
class ProcurementController extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  ProcurementController(this._ref) : super(const AsyncValue.data(null));

  ProcurementRepository get _repo => _ref.read(procurementRepositoryProvider);
  String get _currentDate => _ref.read(selectedProcurementDateProvider);

  /// Toggles item checklist status between pending and procured
  Future<void> toggleItemStatus(String sku, bool isProcured) async {
    state = const AsyncValue.loading();
    try {
      await _repo.toggleItemStatus(_currentDate, sku, isProcured);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Updates whole manifest status (e.g. pending_procurement, in_procurement, procured)
  Future<void> updateManifestStatus(ManifestStatus status) async {
    state = const AsyncValue.loading();
    try {
      await _repo.updateManifestStatus(_currentDate, status);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Changes the active date filter
  void selectDate(String date) {
    _ref.read(selectedProcurementDateProvider.notifier).state = date;
  }

  /// 1-Tap CSV export: Copies standardized procurement CSV payload to clipboard
  Future<bool> exportCsvToClipboard(String csvContent) async {
    try {
      await Clipboard.setData(ClipboardData(text: csvContent));
      return true;
    } catch (e) {
      return false;
    }
  }
}

final procurementControllerProvider =
    StateNotifierProvider<ProcurementController, AsyncValue<void>>((ref) {
  return ProcurementController(ref);
});
