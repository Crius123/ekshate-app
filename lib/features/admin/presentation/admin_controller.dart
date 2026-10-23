import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/admin_metrics.dart';
import '../domain/withdrawal_request.dart';
import '../domain/scheduled_deal_input.dart';
import '../data/admin_repository.dart';

final adminMetricsProvider = StreamProvider<AdminMetrics>((ref) {
  final repo = ref.watch(adminRepositoryProvider);
  return repo.watchOperationalMetrics();
});

final withdrawalFilterProvider = StateProvider<String>((ref) => 'pending');

final withdrawalRequestsProvider = StreamProvider<List<WithdrawalRequest>>((ref) {
  final repo = ref.watch(adminRepositoryProvider);
  final filter = ref.watch(withdrawalFilterProvider);
  return repo.watchWithdrawalRequests(filter);
});

class AdminActionState {
  final bool isLoading;
  final String? successMessage;
  final String? errorMessage;

  const AdminActionState({
    this.isLoading = false,
    this.successMessage,
    this.errorMessage,
  });

  AdminActionState copyWith({
    bool? isLoading,
    String? successMessage,
    String? errorMessage,
  }) {
    return AdminActionState(
      isLoading: isLoading ?? this.isLoading,
      successMessage: successMessage,
      errorMessage: errorMessage,
    );
  }
}

class AdminActionController extends StateNotifier<AdminActionState> {
  final AdminRepository _repository;

  AdminActionController(this._repository) : super(const AdminActionState());

  void clearStatus() {
    state = const AdminActionState();
  }

  Future<bool> reviewWithdrawal({
    required String requestId,
    required String action,
    String? rejectionReason,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null, successMessage: null);
    try {
      await _repository.reviewWithdrawal(
        requestId: requestId,
        action: action,
        rejectionReason: rejectionReason,
      );
      final msg = action == 'approve'
          ? 'Withdrawal request $requestId approved successfully. Funds disbursed.'
          : 'Withdrawal request $requestId rejected.';
      state = state.copyWith(isLoading: false, successMessage: msg);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> scheduleDeal(ScheduledDealInput deal) async {
    state = state.copyWith(isLoading: true, errorMessage: null, successMessage: null);
    try {
      await _repository.scheduleDailyDeal(deal);
      state = state.copyWith(
        isLoading: false,
        successMessage: 'Successfully scheduled "${deal.productTitle}" for ${deal.date} with Bucket #1.',
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<String?> triggerEmergencySettlement([String? date]) async {
    state = state.copyWith(isLoading: true, errorMessage: null, successMessage: null);
    try {
      final summary = await _repository.triggerEmergencySettlement(date);
      state = state.copyWith(isLoading: false, successMessage: summary);
      return summary;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return null;
    }
  }

  Future<String?> triggerManualDispatch([String? date, String? preferredCourier]) async {
    state = state.copyWith(isLoading: true, errorMessage: null, successMessage: null);
    try {
      final summary = await _repository.triggerManualDispatch(date, preferredCourier);
      state = state.copyWith(isLoading: false, successMessage: summary);
      return summary;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return null;
    }
  }
}

final adminActionControllerProvider =
    StateNotifierProvider<AdminActionController, AdminActionState>((ref) {
  final repo = ref.watch(adminRepositoryProvider);
  return AdminActionController(repo);
});
