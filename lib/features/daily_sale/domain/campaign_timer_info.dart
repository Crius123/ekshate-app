enum CampaignPhase {
  preview,
  active,
  settling,
  closed,
}

class CampaignTimerInfo {
  final CampaignPhase phase;
  final String phaseLabel; // e.g. 'Preview Mode' or 'Active'
  final String targetLabel; // e.g. 'Countdown to 10:00 AM BDT' or 'Countdown to 11:59 PM BDT'
  final Duration remaining;
  final String hours;
  final String minutes;
  final String seconds;
  final String formattedCountdown; // e.g. '01:30:00'
  final double progressPercent;

  const CampaignTimerInfo({
    required this.phase,
    required this.phaseLabel,
    required this.targetLabel,
    required this.remaining,
    required this.hours,
    required this.minutes,
    required this.seconds,
    required this.formattedCountdown,
    this.progressPercent = 0.0,
  });

  bool get isPreview => phase == CampaignPhase.preview;
  bool get isActive => phase == CampaignPhase.active;
}

/// Calculates countdown timer state based on Bangladesh Standard Time (BDT / UTC+6).
///
/// Preview Mode window: 12:00 AM – 10:00 AM BDT (Countdown to 10:00 AM BDT).
/// Active window: 10:00 AM – 11:59 PM BDT (Countdown to 11:59 PM BDT).
CampaignTimerInfo calculateCampaignTimerInfo(
  DateTime bdtNow, {
  String? overrideStatus,
}) {
  final isForcedPreview = overrideStatus == 'preview';
  final isForcedActive = overrideStatus == 'active';

  final bool isPreview;
  if (isForcedPreview) {
    isPreview = true;
  } else if (isForcedActive) {
    isPreview = false;
  } else {
    // Automatic clock-based transition
    isPreview = bdtNow.hour < 10;
  }

  final DateTime target;
  final CampaignPhase phase;
  final String phaseLabel;
  final String targetLabel;
  final double progressPercent;

  if (isPreview) {
    phase = CampaignPhase.preview;
    phaseLabel = 'Preview Mode';
    targetLabel = 'Countdown to 10:00 AM BDT';

    // Target is 10:00:00 AM today (or tomorrow if forced preview when past 10:00 AM)
    DateTime tentativeTarget = DateTime(bdtNow.year, bdtNow.month, bdtNow.day, 10, 0, 0);
    if (bdtNow.isAfter(tentativeTarget)) {
      tentativeTarget = tentativeTarget.add(const Duration(days: 1));
    }
    target = tentativeTarget;

    // Window length: 10 hours (from 00:00 to 10:00 = 36000 seconds)
    final diffSeconds = target.difference(bdtNow).inSeconds;
    const windowSeconds = 10 * 3600;
    progressPercent = ((windowSeconds - diffSeconds) / windowSeconds).clamp(0.0, 1.0);
  } else {
    phase = CampaignPhase.active;
    phaseLabel = 'Active';
    targetLabel = 'Countdown to 11:59 PM BDT';

    // Target is 11:59:00 PM today
    DateTime tentativeTarget = DateTime(bdtNow.year, bdtNow.month, bdtNow.day, 23, 59, 0);
    if (bdtNow.isAfter(tentativeTarget)) {
      tentativeTarget = tentativeTarget.add(const Duration(days: 1));
    }
    target = tentativeTarget;

    // Window length: 13 hours 59 minutes (from 10:00 to 23:59 = 50340 seconds)
    final diffSeconds = target.difference(bdtNow).inSeconds;
    const windowSeconds = 13 * 3600 + 59 * 60;
    progressPercent = ((windowSeconds - diffSeconds) / windowSeconds).clamp(0.0, 1.0);
  }

  Duration remaining = target.difference(bdtNow);
  if (remaining.isNegative) {
    remaining = Duration.zero;
  }

  final totalSeconds = remaining.inSeconds;
  final h = totalSeconds ~/ 3600;
  final m = (totalSeconds % 3600) ~/ 60;
  final s = totalSeconds % 60;

  final hours = h.toString().padLeft(2, '0');
  final minutes = m.toString().padLeft(2, '0');
  final seconds = s.toString().padLeft(2, '0');
  final formattedCountdown = '$hours:$minutes:$seconds';

  return CampaignTimerInfo(
    phase: phase,
    phaseLabel: phaseLabel,
    targetLabel: targetLabel,
    remaining: remaining,
    hours: hours,
    minutes: minutes,
    seconds: seconds,
    formattedCountdown: formattedCountdown,
    progressPercent: progressPercent,
  );
}
