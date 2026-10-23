import 'package:flutter_test/flutter_test.dart';
import 'package:ekshate_app/features/auth/data/auth_repository.dart';
import 'package:ekshate_app/features/auth/domain/user_profile.dart';
import 'package:ekshate_app/features/admin/data/admin_repository.dart';
import 'package:ekshate_app/features/admin/domain/scheduled_deal_input.dart';

void main() {
  late MockAuthRepository mockAuthRepo;
  late MockAdminRepository adminRepo;

  setUp(() {
    mockAuthRepo = MockAuthRepository(
      initialUser: const UserProfile(
        uid: 'cust_01',
        phoneNumber: '+8801711000001',
        displayName: 'Sheikh Buyer',
        availableBalance: 5000.0,
        escrowBalance: 1000.0,
        role: 'customer',
      ),
    );

    adminRepo = MockAdminRepository(authRepository: mockAuthRepo);
  });

  tearDown(() {
    adminRepo.dispose();
  });

  group('MockAdminRepository Tests', () {
    test('getOperationalMetrics and watchOperationalMetrics return valid metrics', () async {
      final metrics = await adminRepo.getOperationalMetrics();
      expect(metrics.campaignStatus, 'active');
      expect(metrics.gmv, 148500.0);
      expect(metrics.escrowVolume, 34200.0);
      expect(metrics.pendingDispatchCount, 12);
      expect(metrics.bucketMomentum.length, 3);
      expect(metrics.averageFillPercentage, 79.0);

      final streamEmission = await adminRepo.watchOperationalMetrics().first;
      expect(streamEmission.gmv, 148500.0);
    });

    test('getWithdrawalRequests filters requests correctly', () async {
      final all = await adminRepo.getWithdrawalRequests('all');
      expect(all.length, 4);

      final pending = await adminRepo.getWithdrawalRequests('pending');
      expect(pending.every((w) => w.status == 'pending'), true);
      expect(pending.length, 2);

      final approved = await adminRepo.getWithdrawalRequests('approved');
      expect(approved.length, 1);
      expect(approved.first.status, 'approved');

      final rejected = await adminRepo.getWithdrawalRequests('rejected');
      expect(rejected.length, 1);
      expect(rejected.first.status, 'rejected');
    });

    test('reviewWithdrawal: approving debits user available balance and updates request status', () async {
      final userRepo = MockAuthRepository(
        initialUser: const UserProfile(
          uid: 'user_dev_01',
          availableBalance: 4000.0,
          role: 'customer',
        ),
      );
      final repo = MockAdminRepository(authRepository: userRepo);

      await repo.reviewWithdrawal(
        requestId: 'wreq_101',
        action: 'approve',
      );

      final requests = await repo.getWithdrawalRequests('all');
      final reviewed = requests.firstWhere((w) => w.id == 'wreq_101');
      expect(reviewed.status, 'approved');
      expect(reviewed.trxId, isNotNull);
      expect(reviewed.reviewedAt, isNotNull);

      // Customer available balance should be debited by 1,500: 4,000 -> 2,500
      expect(userRepo.currentUser?.availableBalance, 2500.0);

      // Pending withdrawals count should be decremented
      final metrics = await repo.getOperationalMetrics();
      expect(metrics.pendingWithdrawalsCount, 1);
      repo.dispose();
    });

    test('reviewWithdrawal: rejecting preserves customer balance and saves rejection reason', () async {
      final userRepo = MockAuthRepository(
        initialUser: const UserProfile(
          uid: 'usr_buyer_99',
          availableBalance: 8000.0,
          role: 'customer',
        ),
      );
      final repo = MockAdminRepository(authRepository: userRepo);

      await repo.reviewWithdrawal(
        requestId: 'wreq_102',
        action: 'reject',
        rejectionReason: 'Bank routing number incorrect.',
      );

      final requests = await repo.getWithdrawalRequests('all');
      final rejected = requests.firstWhere((w) => w.id == 'wreq_102');
      expect(rejected.status, 'rejected');
      expect(rejected.rejectionReason, 'Bank routing number incorrect.');

      // Balance untouched
      expect(userRepo.currentUser?.availableBalance, 8000.0);
      repo.dispose();
    });

    test('reviewWithdrawal: throws StateError on non-existent or already reviewed request', () async {
      expect(
        () => adminRepo.reviewWithdrawal(requestId: 'non_existent_req', action: 'approve'),
        throwsStateError,
      );

      // wreq_103 is already approved
      expect(
        () => adminRepo.reviewWithdrawal(requestId: 'wreq_103', action: 'approve'),
        throwsStateError,
      );
    });

    test('scheduleDailyDeal: provisions listing with Bucket #1 and updates metrics', () async {
      const deal = ScheduledDealInput(
        date: '2026-10-25',
        productTitle: 'Bogura Red Chili',
        category: 'Cooking Essentials',
        unit: 'kg',
        marketPrice: 350.0,
        unitPrice: 280.0,
        moqThreshold: 40.0,
        imageUrl: 'https://cdn.ekshate.com/chili.jpg',
      );

      await adminRepo.scheduleDailyDeal(deal);

      final metrics = await adminRepo.getOperationalMetrics();
      expect(metrics.listingsCount, 4);
      final added = metrics.bucketMomentum.firstWhere((m) => m.productTitle == 'Bogura Red Chili');
      expect(added.activeBucketNumber, 1);
      expect(added.moqThreshold, 40.0);
      expect(added.currentQuantity, 0.0);
      expect(added.discountPercent, 20.0);
    });

    test('triggerEmergencySettlement: marks campaign settled and zeroes escrow volume', () async {
      final summary = await adminRepo.triggerEmergencySettlement('2026-10-24');
      expect(summary, contains('settlement complete'));

      final metrics = await adminRepo.getOperationalMetrics();
      expect(metrics.campaignStatus, 'settled');
      expect(metrics.escrowVolume, 0.0);
    });

    test('triggerManualDispatch: resets pending dispatches and increments dispatched count', () async {
      final summary = await adminRepo.triggerManualDispatch('2026-10-24', 'Steadfast');
      expect(summary, contains('Steadfast'));

      final metrics = await adminRepo.getOperationalMetrics();
      expect(metrics.pendingDispatchCount, 0);
      expect(metrics.dispatchedOrdersCount, 20); // 8 + 12
    });

    test('submitWithdrawalRequest: creates pending request and updates pending metrics', () async {
      final req = await adminRepo.submitWithdrawalRequest(
        userId: 'cust_01',
        amount: 2000.0,
        payoutMethod: 'bkash',
        accountNumber: '01711000001',
      );

      expect(req.status, 'pending');
      expect(req.amount, 2000.0);

      final pending = await adminRepo.getWithdrawalRequests('pending');
      expect(pending.any((w) => w.id == req.id), true);

      // Should throw when amount exceeds available balance (5000 available)
      expect(
        () => adminRepo.submitWithdrawalRequest(
          userId: 'cust_01',
          amount: 9000.0,
          payoutMethod: 'bkash',
          accountNumber: '01711000001',
        ),
        throwsStateError,
      );
    });
  });
}
