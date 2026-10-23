import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/data/auth_repository.dart';
import '../../wallet/data/wallet_repository.dart';
import '../domain/admin_metrics.dart';
import '../domain/withdrawal_request.dart';
import '../domain/scheduled_deal_input.dart';

abstract class AdminRepository {
  Future<AdminMetrics> getOperationalMetrics([String? date]);
  Stream<AdminMetrics> watchOperationalMetrics([String? date]);
  Future<List<WithdrawalRequest>> getWithdrawalRequests([String? statusFilter]);
  Stream<List<WithdrawalRequest>> watchWithdrawalRequests([String? statusFilter]);
  Future<void> reviewWithdrawal({
    required String requestId,
    required String action,
    String? rejectionReason,
    String? adminNotes,
  });
  Future<void> scheduleDailyDeal(ScheduledDealInput deal);
  Future<String> triggerEmergencySettlement([String? date]);
  Future<String> triggerManualDispatch([String? date, String? preferredCourier]);
  Future<WithdrawalRequest> submitWithdrawalRequest({
    required String userId,
    required double amount,
    required String payoutMethod,
    required String accountNumber,
    String? bankName,
    String? accountHolderName,
  });
}

class MockAdminRepository implements AdminRepository {
  final AuthRepository authRepository;
  final WalletRepository? walletRepository;
  final Duration simulatedDelay;

  final StreamController<AdminMetrics> _metricsController = StreamController<AdminMetrics>.broadcast();
  final StreamController<List<WithdrawalRequest>> _withdrawalsController =
      StreamController<List<WithdrawalRequest>>.broadcast();

  AdminMetrics _currentMetrics;
  final List<WithdrawalRequest> _withdrawals = [];
  final List<ScheduledDealInput> _scheduledDeals = [];

  MockAdminRepository({
    required this.authRepository,
    this.walletRepository,
    this.simulatedDelay = Duration.zero,
    AdminMetrics? initialMetrics,
    List<WithdrawalRequest>? initialWithdrawals,
  }) : _currentMetrics = initialMetrics ?? _defaultSeedMetrics {
    if (initialWithdrawals != null) {
      _withdrawals.addAll(initialWithdrawals);
    } else {
      _seedDefaultWithdrawals();
    }
  }

  static AdminMetrics get _defaultSeedMetrics => AdminMetrics(
        date: _getTodayDateString(),
        campaignStatus: 'active',
        gmv: 148500.0,
        escrowVolume: 34200.0,
        totalOrdersCount: 64,
        pendingEscrowOrdersCount: 18,
        confirmedOrdersCount: 38,
        dispatchedOrdersCount: 8,
        refundedOrdersCount: 0,
        pendingDispatchCount: 12,
        listingsCount: 3,
        averageFillPercentage: 79.0,
        bucketMomentum: [
          const BucketMomentum(
            listingId: 'list_chicken_01',
            productId: 'prod_chicken_01',
            productTitle: 'Organic Sonali Chicken',
            category: 'Fresh Meat & Poultry',
            unit: 'kg',
            marketPrice: 320.0,
            unitPrice: 240.0,
            discountPercent: 25.0,
            activeBucketNumber: 1,
            moqThreshold: 50.0,
            currentQuantity: 42.5,
            remainingCapacity: 7.5,
            fillPercentage: 85.0,
            orderCount: 16,
            status: 'open',
          ),
          const BucketMomentum(
            listingId: 'list_potato_01',
            productId: 'prod_potato_01',
            productTitle: 'Fresh Munshiganj Potato',
            category: 'Vegetables & Greens',
            unit: 'kg',
            marketPrice: 65.0,
            unitPrice: 48.0,
            discountPercent: 26.2,
            activeBucketNumber: 2,
            moqThreshold: 100.0,
            currentQuantity: 92.0,
            remainingCapacity: 8.0,
            fillPercentage: 92.0,
            orderCount: 28,
            status: 'open',
          ),
          const BucketMomentum(
            listingId: 'list_rice_01',
            productId: 'prod_rice_01',
            productTitle: 'Premium Miniket Rice',
            category: 'Staples & Grains',
            unit: 'kg',
            marketPrice: 85.0,
            unitPrice: 68.0,
            discountPercent: 20.0,
            activeBucketNumber: 1,
            moqThreshold: 200.0,
            currentQuantity: 120.0,
            remainingCapacity: 80.0,
            fillPercentage: 60.0,
            orderCount: 20,
            status: 'open',
          ),
        ],
        pendingWithdrawalsCount: 2,
        pendingWithdrawalsAmount: 4700.0,
      );

  void _seedDefaultWithdrawals() {
    final now = DateTime.now();
    _withdrawals.addAll([
      WithdrawalRequest(
        id: 'wreq_101',
        userId: 'user_dev_01',
        amount: 1500.0,
        payoutMethod: 'bkash',
        accountNumber: '01711000001',
        status: 'pending',
        createdAt: now.subtract(const Duration(minutes: 45)),
      ),
      WithdrawalRequest(
        id: 'wreq_102',
        userId: 'usr_buyer_99',
        amount: 3200.0,
        payoutMethod: 'bank',
        accountNumber: '1501203498110001',
        bankName: 'BRAC Bank PLC',
        accountHolderName: 'Tanvir Ahmed',
        status: 'pending',
        createdAt: now.subtract(const Duration(hours: 2, minutes: 15)),
      ),
      WithdrawalRequest(
        id: 'wreq_103',
        userId: 'usr_buyer_88',
        amount: 800.0,
        payoutMethod: 'bkash',
        accountNumber: '01819998877',
        status: 'approved',
        reviewedBy: 'admin_dev_01',
        reviewedAt: now.subtract(const Duration(hours: 5)),
        trxId: 'trx_payout_wreq_103',
        createdAt: now.subtract(const Duration(hours: 6)),
      ),
      WithdrawalRequest(
        id: 'wreq_104',
        userId: 'usr_buyer_77',
        amount: 1200.0,
        payoutMethod: 'nagad',
        accountNumber: '01912345678',
        status: 'rejected',
        rejectionReason: 'Invalid personal wallet account. Requires registered bKash/Nagad number.',
        reviewedBy: 'admin_dev_01',
        reviewedAt: now.subtract(const Duration(hours: 8)),
        createdAt: now.subtract(const Duration(hours: 10)),
      ),
    ]);
  }

  static String _getTodayDateString() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  @override
  Future<AdminMetrics> getOperationalMetrics([String? date]) async {
    if (simulatedDelay > Duration.zero) await Future.delayed(simulatedDelay);
    return _currentMetrics;
  }

  @override
  Stream<AdminMetrics> watchOperationalMetrics([String? date]) async* {
    yield _currentMetrics;
    yield* _metricsController.stream;
  }

  @override
  Future<List<WithdrawalRequest>> getWithdrawalRequests([String? statusFilter]) async {
    if (simulatedDelay > Duration.zero) await Future.delayed(simulatedDelay);
    if (statusFilter == null || statusFilter.isEmpty || statusFilter.toLowerCase() == 'all') {
      return List.unmodifiable(_withdrawals);
    }
    return _withdrawals.where((w) => w.status.toLowerCase() == statusFilter.toLowerCase()).toList();
  }

  @override
  Stream<List<WithdrawalRequest>> watchWithdrawalRequests([String? statusFilter]) async* {
    yield await getWithdrawalRequests(statusFilter);
    yield* _withdrawalsController.stream.map((list) {
      if (statusFilter == null || statusFilter.isEmpty || statusFilter.toLowerCase() == 'all') {
        return list;
      }
      return list.where((w) => w.status.toLowerCase() == statusFilter.toLowerCase()).toList();
    });
  }

  @override
  Future<void> reviewWithdrawal({
    required String requestId,
    required String action,
    String? rejectionReason,
    String? adminNotes,
  }) async {
    if (simulatedDelay > Duration.zero) await Future.delayed(simulatedDelay);

    final index = _withdrawals.indexWhere((w) => w.id == requestId);
    if (index == -1) {
      throw StateError('Withdrawal request $requestId not found');
    }

    final current = _withdrawals[index];
    if (current.status != 'pending') {
      throw StateError('Withdrawal request $requestId is already ${current.status}');
    }

    final now = DateTime.now();

    if (action.toLowerCase() == 'approve') {
      final trxId = 'trx_payout_${requestId}_${now.millisecondsSinceEpoch}';

      // Debit customer balance atomically
      authRepository.updateBalances(
        uid: current.userId,
        availableBalanceDelta: -current.amount,
      );

      final updated = current.copyWith(
        status: 'approved',
        reviewedBy: authRepository.currentUser?.uid ?? 'admin_dev_01',
        reviewedAt: now,
        trxId: trxId,
        updatedAt: now,
      );
      _withdrawals[index] = updated;

      // Update pending metrics
      final pendingList = _withdrawals.where((w) => w.status == 'pending').toList();
      final pendingAmount = pendingList.fold<double>(0.0, (acc, item) => acc + item.amount);

      _currentMetrics = _currentMetrics.copyWith(
        pendingWithdrawalsCount: pendingList.length,
        pendingWithdrawalsAmount: pendingAmount,
      );
    } else {
      final updated = current.copyWith(
        status: 'rejected',
        rejectionReason: rejectionReason ?? 'Rejected by platform operator',
        reviewedBy: authRepository.currentUser?.uid ?? 'admin_dev_01',
        reviewedAt: now,
        updatedAt: now,
      );
      _withdrawals[index] = updated;

      final pendingList = _withdrawals.where((w) => w.status == 'pending').toList();
      final pendingAmount = pendingList.fold<double>(0.0, (acc, item) => acc + item.amount);

      _currentMetrics = _currentMetrics.copyWith(
        pendingWithdrawalsCount: pendingList.length,
        pendingWithdrawalsAmount: pendingAmount,
      );
    }

    _withdrawalsController.add(List.unmodifiable(_withdrawals));
    _metricsController.add(_currentMetrics);
  }

  @override
  Future<void> scheduleDailyDeal(ScheduledDealInput deal) async {
    if (simulatedDelay > Duration.zero) await Future.delayed(simulatedDelay);

    if (!deal.isValid) {
      throw ArgumentError('Invalid daily deal parameters. Ensure positive prices and MOQ.');
    }

    _scheduledDeals.add(deal);

    final newMomentum = BucketMomentum(
      listingId: 'list_${deal.date.replaceAll('-', '')}_${deal.productTitle.toLowerCase().replaceAll(' ', '_')}',
      productId: 'prod_${deal.productTitle.toLowerCase().replaceAll(' ', '_')}',
      productTitle: deal.productTitle,
      category: deal.category,
      unit: deal.unit,
      marketPrice: deal.marketPrice,
      unitPrice: deal.unitPrice,
      discountPercent: deal.discountPercent,
      activeBucketNumber: 1,
      moqThreshold: deal.moqThreshold,
      currentQuantity: 0.0,
      remainingCapacity: deal.moqThreshold,
      fillPercentage: 0.0,
      orderCount: 0,
      status: 'open',
    );

    final updatedList = List<BucketMomentum>.from(_currentMetrics.bucketMomentum)..add(newMomentum);
    final totalFill = updatedList.fold<double>(0.0, (sum, m) => sum + m.fillPercentage);
    final avgFill = updatedList.isNotEmpty ? (totalFill / updatedList.length) : 0.0;

    _currentMetrics = _currentMetrics.copyWith(
      listingsCount: updatedList.length,
      averageFillPercentage: double.parse(avgFill.toStringAsFixed(1)),
      bucketMomentum: updatedList,
    );

    _metricsController.add(_currentMetrics);
  }

  @override
  Future<String> triggerEmergencySettlement([String? date]) async {
    if (simulatedDelay > Duration.zero) await Future.delayed(simulatedDelay);

    final targetDate = date ?? _currentMetrics.date;
    _currentMetrics = _currentMetrics.copyWith(
      campaignStatus: 'settled',
      escrowVolume: 0.0,
      confirmedOrdersCount: _currentMetrics.confirmedOrdersCount + _currentMetrics.pendingEscrowOrdersCount,
      pendingEscrowOrdersCount: 0,
    );
    _metricsController.add(_currentMetrics);

    return 'Campaign $targetDate settlement complete: 3 won buckets confirmed, escrow captured permanently.';
  }

  @override
  Future<String> triggerManualDispatch([String? date, String? preferredCourier]) async {
    if (simulatedDelay > Duration.zero) await Future.delayed(simulatedDelay);

    final count = _currentMetrics.pendingDispatchCount;
    final partner = preferredCourier ?? 'Pathao Courier';

    _currentMetrics = _currentMetrics.copyWith(
      pendingDispatchCount: 0,
      dispatchedOrdersCount: _currentMetrics.dispatchedOrdersCount + count,
    );
    _metricsController.add(_currentMetrics);

    return 'Dispatched $count orders via $partner (Batch ID: BATCH-${DateTime.now().millisecondsSinceEpoch}).';
  }

  @override
  Future<WithdrawalRequest> submitWithdrawalRequest({
    required String userId,
    required double amount,
    required String payoutMethod,
    required String accountNumber,
    String? bankName,
    String? accountHolderName,
  }) async {
    if (simulatedDelay > Duration.zero) await Future.delayed(simulatedDelay);

    if (amount <= 0) {
      throw ArgumentError('Withdrawal amount must be greater than zero.');
    }

    final user = authRepository.currentUser;
    if (user == null || user.uid != userId) {
      throw StateError('User authentication mismatch or not logged in.');
    }

    if (user.availableBalance < amount) {
      throw StateError('Insufficient available balance: ৳${user.availableBalance} available, ৳$amount requested.');
    }

    final requestId = 'wreq_${DateTime.now().millisecondsSinceEpoch}';
    final newRequest = WithdrawalRequest(
      id: requestId,
      userId: userId,
      amount: amount,
      payoutMethod: payoutMethod,
      accountNumber: accountNumber,
      bankName: bankName,
      accountHolderName: accountHolderName,
      status: 'pending',
      createdAt: DateTime.now(),
    );

    _withdrawals.insert(0, newRequest);
    _withdrawalsController.add(List.unmodifiable(_withdrawals));

    final pendingList = _withdrawals.where((w) => w.status == 'pending').toList();
    final pendingAmount = pendingList.fold<double>(0.0, (acc, item) => acc + item.amount);

    _currentMetrics = _currentMetrics.copyWith(
      pendingWithdrawalsCount: pendingList.length,
      pendingWithdrawalsAmount: pendingAmount,
    );
    _metricsController.add(_currentMetrics);

    return newRequest;
  }

  void dispose() {
    _metricsController.close();
    _withdrawalsController.close();
  }
}

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  final authRepo = ref.watch(authRepositoryProvider);
  return MockAdminRepository(authRepository: authRepo);
});
