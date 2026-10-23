import 'package:flutter_test/flutter_test.dart';
import 'package:ekshate_app/features/auth/data/auth_repository.dart';
import 'package:ekshate_app/features/auth/domain/user_profile.dart';
import 'package:ekshate_app/features/admin/data/admin_repository.dart';
import 'package:ekshate_app/features/admin/domain/scheduled_deal_input.dart';
import 'package:ekshate_app/features/admin/presentation/admin_controller.dart';

void main() {
  late MockAuthRepository mockAuthRepo;
  late MockAdminRepository adminRepo;
  late AdminActionController controller;

  setUp(() {
    mockAuthRepo = MockAuthRepository(
      initialUser: const UserProfile(
        uid: 'admin_test_01',
        displayName: 'Test Admin',
        role: 'admin',
        availableBalance: 10000.0,
      ),
    );
    adminRepo = MockAdminRepository(authRepository: mockAuthRepo);
    controller = AdminActionController(adminRepo);
  });

  tearDown(() {
    adminRepo.dispose();
  });

  group('AdminActionController State & Actions Tests', () {
    test('initial state has no loading, error or success message', () {
      expect(controller.state.isLoading, false);
      expect(controller.state.successMessage, isNull);
      expect(controller.state.errorMessage, isNull);
    });

    test('reviewWithdrawal successfully approves request and sets successMessage', () async {
      mockAuthRepo.seedUser(const UserProfile(
        uid: 'user_dev_01',
        availableBalance: 5000.0,
      ));

      final success = await controller.reviewWithdrawal(
        requestId: 'wreq_101',
        action: 'approve',
      );

      expect(success, true);
      expect(controller.state.isLoading, false);
      expect(controller.state.successMessage, contains('approved successfully'));
      expect(controller.state.errorMessage, isNull);
    });

    test('reviewWithdrawal sets error state when action fails on invalid requestId', () async {
      final success = await controller.reviewWithdrawal(
        requestId: 'invalid_req_id',
        action: 'approve',
      );

      expect(success, false);
      expect(controller.state.isLoading, false);
      expect(controller.state.errorMessage, isNotNull);
      expect(controller.state.successMessage, isNull);
    });

    test('scheduleDeal successfully creates deal and updates state', () async {
      const deal = ScheduledDealInput(
        date: '2026-10-25',
        productTitle: 'Fresh Cucumber',
        category: 'Vegetables & Greens',
        unit: 'kg',
        marketPrice: 50.0,
        unitPrice: 35.0,
        moqThreshold: 80.0,
        imageUrl: 'https://cdn.ekshate.com/cucumber.jpg',
      );

      final success = await controller.scheduleDeal(deal);

      expect(success, true);
      expect(controller.state.isLoading, false);
      expect(controller.state.successMessage, contains('Fresh Cucumber'));
    });

    test('scheduleDeal fails and populates errorMessage on invalid parameters', () async {
      const invalidDeal = ScheduledDealInput(
        date: '2026-10-25',
        productTitle: '',
        category: 'Vegetables & Greens',
        unit: 'kg',
        marketPrice: 50.0,
        unitPrice: 60.0, // Invalid!
        moqThreshold: 0.0,
        imageUrl: '',
      );

      final success = await controller.scheduleDeal(invalidDeal);

      expect(success, false);
      expect(controller.state.isLoading, false);
      expect(controller.state.errorMessage, isNotNull);
    });

    test('triggerEmergencySettlement succeeds and sets summary message', () async {
      final summary = await controller.triggerEmergencySettlement('2026-10-24');

      expect(summary, isNotNull);
      expect(controller.state.isLoading, false);
      expect(controller.state.successMessage, contains('settlement complete'));
    });

    test('triggerManualDispatch succeeds and sets summary message', () async {
      final summary = await controller.triggerManualDispatch('2026-10-24', 'RedX');

      expect(summary, isNotNull);
      expect(controller.state.isLoading, false);
      expect(controller.state.successMessage, contains('RedX'));
    });
  });
}
