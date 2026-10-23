import 'package:flutter_test/flutter_test.dart';
import 'package:ekshate_app/features/admin/domain/admin_metrics.dart';
import 'package:ekshate_app/features/admin/domain/withdrawal_request.dart';
import 'package:ekshate_app/features/admin/domain/scheduled_deal_input.dart';

void main() {
  group('AdminMetrics and BucketMomentum Entity Tests', () {
    test('BucketMomentum correctly parses from JSON and serializes', () {
      final json = {
        'listingId': 'list_sonali_01',
        'productId': 'prod_chicken_01',
        'productTitle': 'Organic Sonali Chicken',
        'category': 'Fresh Meat & Poultry',
        'unit': 'kg',
        'marketPrice': 320.0,
        'unitPrice': 240.0,
        'discountPercent': 25.0,
        'activeBucketNumber': 1,
        'moqThreshold': 50.0,
        'currentQuantity': 42.5,
        'remainingCapacity': 7.5,
        'fillPercentage': 85.0,
        'orderCount': 16,
        'status': 'open',
      };

      final momentum = BucketMomentum.fromJson(json);

      expect(momentum.listingId, 'list_sonali_01');
      expect(momentum.productTitle, 'Organic Sonali Chicken');
      expect(momentum.marketPrice, 320.0);
      expect(momentum.unitPrice, 240.0);
      expect(momentum.discountPercent, 25.0);
      expect(momentum.activeBucketNumber, 1);
      expect(momentum.moqThreshold, 50.0);
      expect(momentum.currentQuantity, 42.5);
      expect(momentum.remainingCapacity, 7.5);
      expect(momentum.fillPercentage, 85.0);
      expect(momentum.orderCount, 16);
      expect(momentum.status, 'open');

      final serialized = momentum.toJson();
      expect(serialized['listingId'], 'list_sonali_01');
      expect(serialized['fillPercentage'], 85.0);
    });

    test('AdminMetrics correctly parses from JSON and supports copyWith', () {
      final json = {
        'date': '2026-10-24',
        'campaignStatus': 'active',
        'gmv': 148500.0,
        'escrowVolume': 34200.0,
        'totalOrdersCount': 64,
        'pendingEscrowOrdersCount': 18,
        'confirmedOrdersCount': 38,
        'dispatchedOrdersCount': 8,
        'refundedOrdersCount': 0,
        'pendingDispatchCount': 12,
        'listingsCount': 1,
        'averageFillPercentage': 85.0,
        'bucketMomentum': [
          {
            'listingId': 'list_sonali_01',
            'productId': 'prod_chicken_01',
            'productTitle': 'Organic Sonali Chicken',
            'category': 'Fresh Meat & Poultry',
            'unit': 'kg',
            'marketPrice': 320.0,
            'unitPrice': 240.0,
            'discountPercent': 25.0,
            'activeBucketNumber': 1,
            'moqThreshold': 50.0,
            'currentQuantity': 42.5,
            'remainingCapacity': 7.5,
            'fillPercentage': 85.0,
            'orderCount': 16,
            'status': 'open',
          }
        ],
        'pendingWithdrawalsCount': 2,
        'pendingWithdrawalsAmount': 4700.0,
      };

      final metrics = AdminMetrics.fromJson(json);

      expect(metrics.date, '2026-10-24');
      expect(metrics.campaignStatus, 'active');
      expect(metrics.gmv, 148500.0);
      expect(metrics.escrowVolume, 34200.0);
      expect(metrics.totalOrdersCount, 64);
      expect(metrics.pendingDispatchCount, 12);
      expect(metrics.bucketMomentum.length, 1);
      expect(metrics.pendingWithdrawalsCount, 2);
      expect(metrics.pendingWithdrawalsAmount, 4700.0);

      final updated = metrics.copyWith(gmv: 160000.0, pendingDispatchCount: 0);
      expect(updated.gmv, 160000.0);
      expect(updated.pendingDispatchCount, 0);
      expect(updated.date, '2026-10-24');
    });

    test('AdminMetrics.empty returns zeroed metrics object', () {
      final empty = AdminMetrics.empty(date: '2026-10-25');
      expect(empty.date, '2026-10-25');
      expect(empty.gmv, 0.0);
      expect(empty.escrowVolume, 0.0);
      expect(empty.totalOrdersCount, 0);
      expect(empty.bucketMomentum, isEmpty);
    });
  });

  group('WithdrawalRequest Entity Tests', () {
    test('WithdrawalRequest correctly parses, handles status getters and formatting', () {
      final now = DateTime.now();
      final req = WithdrawalRequest(
        id: 'wreq_999',
        userId: 'usr_customer_01',
        amount: 2500.0,
        payoutMethod: 'bkash',
        accountNumber: '01711223344',
        status: 'pending',
        createdAt: now,
      );

      expect(req.isPending, true);
      expect(req.isApproved, false);
      expect(req.isRejected, false);
      expect(req.formattedAmount, '৳2500');
      expect(req.payoutMethodLabel, 'bKash');

      final approved = req.copyWith(
        status: 'approved',
        reviewedBy: 'admin_01',
        trxId: 'trx_payout_123',
      );
      expect(approved.isApproved, true);
      expect(approved.isPending, false);
      expect(approved.trxId, 'trx_payout_123');

      final bankReq = WithdrawalRequest(
        id: 'wreq_bank',
        userId: 'usr_bank_02',
        amount: 5000.0,
        payoutMethod: 'bank',
        accountNumber: '150120999',
        bankName: 'Eastern Bank PLC',
        createdAt: now,
      );
      expect(bankReq.payoutMethodLabel, 'Bank (Eastern Bank PLC)');
    });
  });

  group('ScheduledDealInput Entity Tests', () {
    test('Calculates discount percent, savings per unit, and validates fields', () {
      const validDeal = ScheduledDealInput(
        date: '2026-10-25',
        productTitle: 'Holland Potato',
        category: 'Vegetables & Greens',
        unit: 'kg',
        marketPrice: 60.0,
        unitPrice: 45.0,
        moqThreshold: 100.0,
        imageUrl: 'https://cdn.ekshate.com/potato.jpg',
      );

      expect(validDeal.savingsPerUnit, 15.0);
      expect(validDeal.discountPercent, 25.0);
      expect(validDeal.isValid, true);

      const invalidDeal = ScheduledDealInput(
        date: '2026-10-25',
        productTitle: '',
        category: 'Vegetables & Greens',
        unit: 'kg',
        marketPrice: 40.0,
        unitPrice: 50.0, // Unit price higher than market price!
        moqThreshold: 0.0,
        imageUrl: '',
      );

      expect(invalidDeal.isValid, false);
      expect(invalidDeal.discountPercent, 0.0);
    });
  });
}
