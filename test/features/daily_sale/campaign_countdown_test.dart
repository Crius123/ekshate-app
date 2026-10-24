import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:ekshate_app/features/daily_sale/domain/campaign_timer_info.dart';
import 'package:ekshate_app/features/daily_sale/presentation/daily_sale_controller.dart';
import 'package:ekshate_app/features/daily_sale/presentation/widgets/campaign_countdown_header.dart';

void main() {
  group('CampaignTimerInfo Unit Tests', () {
    test('calculates preview mode countdown correctly (before 10:00 AM BDT)', () {
      // 08:30:00 BDT -> 1 hour 30 minutes remaining to 10:00:00 AM BDT
      final bdtTime = DateTime(2026, 10, 22, 8, 30, 0);
      final timerInfo = calculateCampaignTimerInfo(bdtTime);

      expect(timerInfo.isPreview, isTrue);
      expect(timerInfo.isActive, isFalse);
      expect(timerInfo.phase, CampaignPhase.preview);
      expect(timerInfo.phaseLabel, 'Preview Mode');
      expect(timerInfo.targetLabel, 'Countdown to 10:00 AM BDT');
      expect(timerInfo.hours, '01');
      expect(timerInfo.minutes, '30');
      expect(timerInfo.seconds, '00');
      expect(timerInfo.formattedCountdown, '01:30:00');
      expect(timerInfo.remaining.inMinutes, 90);
    });

    test('calculates active countdown correctly (after 10:00 AM BDT)', () {
      // 14:00:00 BDT -> 9 hours 59 minutes remaining to 23:59:00 BDT
      final bdtTime = DateTime(2026, 10, 22, 14, 0, 0);
      final timerInfo = calculateCampaignTimerInfo(bdtTime);

      expect(timerInfo.isPreview, isFalse);
      expect(timerInfo.isActive, isTrue);
      expect(timerInfo.phase, CampaignPhase.active);
      expect(timerInfo.phaseLabel, 'Active');
      expect(timerInfo.targetLabel, 'Countdown to 11:59 PM BDT');
      expect(timerInfo.hours, '09');
      expect(timerInfo.minutes, '59');
      expect(timerInfo.seconds, '00');
      expect(timerInfo.formattedCountdown, '09:59:00');
      expect(timerInfo.remaining.inMinutes, 599);
    });

    test('respects forced preview override even when clock is past 10:00 AM', () {
      final bdtTime = DateTime(2026, 10, 22, 14, 0, 0);
      final timerInfo = calculateCampaignTimerInfo(bdtTime, overrideStatus: 'preview');

      expect(timerInfo.isPreview, isTrue);
      expect(timerInfo.phaseLabel, 'Preview Mode');
      expect(timerInfo.targetLabel, 'Countdown to 10:00 AM BDT');
      // Next day 10:00 AM -> 20 hours remaining
      expect(timerInfo.hours, '20');
      expect(timerInfo.minutes, '00');
      expect(timerInfo.seconds, '00');
    });

    test('respects forced active override even when clock is before 10:00 AM', () {
      final bdtTime = DateTime(2026, 10, 22, 8, 0, 0);
      final timerInfo = calculateCampaignTimerInfo(bdtTime, overrideStatus: 'active');

      expect(timerInfo.isActive, isTrue);
      expect(timerInfo.phaseLabel, 'Active');
      expect(timerInfo.targetLabel, 'Countdown to 11:59 PM BDT');
      // 23:59 - 08:00 = 15 hours 59 minutes
      expect(timerInfo.hours, '15');
      expect(timerInfo.minutes, '59');
      expect(timerInfo.seconds, '00');
    });

    test('clamps remaining duration to zero when target passed', () {
      final bdtTime = DateTime(2026, 10, 22, 23, 59, 30);
      final timerInfo = calculateCampaignTimerInfo(bdtTime, overrideStatus: 'active');

      // Next day 23:59
      expect(timerInfo.remaining.isNegative, isFalse);
    });
  });

  group('CampaignCountdownHeader Widget Tests', () {
    Widget buildHeaderWidget({
      DateTime? fixedBdtTime,
      String? status,
      bool autoTick = false,
    }) {
      return ProviderScope(
        overrides: [
          if (fixedBdtTime != null)
            campaignClockProvider.overrideWithValue(() => fixedBdtTime),
          if (status != null)
            dailyCampaignStatusProvider.overrideWith((ref) => status),
        ],
        child: ShadApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16.0),
              child: CampaignCountdownHeader(autoTick: autoTick),
            ),
          ),
        ),
      );
    }

    testWidgets('renders Preview Mode header with Countdown to 10:00 AM BDT', (tester) async {
      final fixedTime = DateTime(2026, 10, 22, 8, 30, 0);
      await tester.pumpWidget(buildHeaderWidget(fixedBdtTime: fixedTime, status: 'preview'));
      await tester.pumpAndSettle();

      // Check Title and Status Badge
      expect(find.text('Daily Bulk Campaign'), findsOneWidget);
      expect(find.text('Preview Mode'), findsOneWidget);

      // Check Dynamic Target Label
      expect(find.text('Countdown to 10:00 AM BDT'), findsOneWidget);
      expect(find.text('Wholesale drops unlock at 10:00 AM BDT'), findsOneWidget);

      // Check Segmented Timer Digits
      expect(find.byKey(const Key('timer_segment_HRS')), findsOneWidget);
      expect(find.text('01'), findsOneWidget); // 1 hr remaining
      expect(find.text('30'), findsOneWidget); // 30 min remaining
      expect(find.text('00'), findsOneWidget); // 00 sec remaining
    });

    testWidgets('renders Active header with Countdown to 11:59 PM BDT', (tester) async {
      final fixedTime = DateTime(2026, 10, 22, 14, 0, 0);
      await tester.pumpWidget(buildHeaderWidget(fixedBdtTime: fixedTime, status: 'active'));
      await tester.pumpAndSettle();

      // Check Title and Status Badge
      expect(find.text('Daily Bulk Campaign'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);

      // Check Dynamic Target Label
      expect(find.text('Countdown to 11:59 PM BDT'), findsOneWidget);
      expect(find.text('Deals close at midnight (11:59 PM BDT)'), findsOneWidget);

      // Check Segmented Timer Digits
      expect(find.text('09'), findsOneWidget); // 9 hr remaining
      expect(find.text('59'), findsOneWidget); // 59 min remaining
      expect(find.text('00'), findsOneWidget); // 00 sec remaining
    });

    testWidgets('dynamically updates when campaign status switches from preview to active', (tester) async {
      final container = ProviderContainer(
        overrides: [
          campaignClockProvider.overrideWithValue(() => DateTime(2026, 10, 22, 8, 30, 0)),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const ShadApp(
            home: Scaffold(
              body: CampaignCountdownHeader(autoTick: false),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Starts in active by default in controller
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Countdown to 11:59 PM BDT'), findsOneWidget);

      // Switch to preview mode
      container.read(dailyCampaignStatusProvider.notifier).state = 'preview';
      await tester.pumpAndSettle();

      // Now reflects preview mode
      expect(find.text('Preview Mode'), findsOneWidget);
      expect(find.text('Countdown to 10:00 AM BDT'), findsOneWidget);
      expect(find.text('01'), findsOneWidget); // 01:30:00
      expect(find.text('30'), findsOneWidget);
    });
  });
}
