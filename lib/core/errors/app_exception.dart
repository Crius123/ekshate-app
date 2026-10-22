/// Strongly-typed domain exceptions for the Ekshate platform
sealed class AppException implements Exception {
  final String message;
  final String? code;

  const AppException(this.message, {this.code});

  @override
  String toString() => message;
}

class InsufficientWalletBalanceException extends AppException {
  final double requiredAmount;
  final double availableBalance;

  InsufficientWalletBalanceException({
    required this.requiredAmount,
    required this.availableBalance,
  }) : super(
          'Insufficient wallet balance. Required: ৳${requiredAmount.toStringAsFixed(0)}, Available: ৳${availableBalance.toStringAsFixed(0)}.',
          code: 'INSUFFICIENT_FUNDS',
        );
}

class BucketCapacityExceededException extends AppException {
  final double requestedQuantity;
  final double remainingCapacity;

  BucketCapacityExceededException({
    required this.requestedQuantity,
    required this.remainingCapacity,
  }) : super(
          'Requested quantity (${requestedQuantity.toStringAsFixed(1)} kg) exceeds remaining bucket capacity (${remainingCapacity.toStringAsFixed(1)} kg). Orders cannot cross buckets.',
          code: 'CAPACITY_EXCEEDED',
        );
}

class CampaignInactiveException extends AppException {
  const CampaignInactiveException([String status = 'preview'])
      : super(
          'Daily campaign is in $status mode. Ordering opens from 10:00 AM to 11:59 PM BDT.',
          code: 'CAMPAIGN_INACTIVE',
        );
}

class NetworkOfflineException extends AppException {
  const NetworkOfflineException()
      : super(
          'No internet connection detected. Please check your data or Wi-Fi.',
          code: 'NETWORK_OFFLINE',
        );
}

class InvalidPhoneNumberException extends AppException {
  const InvalidPhoneNumberException([
    super.message = 'Please enter a valid 11-digit Bangladeshi mobile number starting with 01 (e.g. 017XXXXXXXX).',
  ]) : super(code: 'INVALID_PHONE_NUMBER');
}

class InvalidOtpException extends AppException {
  const InvalidOtpException([
    super.message = 'The verification code entered is invalid. Please check your SMS and try again.',
  ]) : super(code: 'INVALID_OTP');
}

class ExpiredOtpException extends AppException {
  const ExpiredOtpException([
    super.message = 'This verification code has expired. Please request a new code.',
  ]) : super(code: 'EXPIRED_OTP');
}

class AuthNetworkTimeoutException extends AppException {
  const AuthNetworkTimeoutException([
    super.message = 'Connection timed out while sending or verifying OTP. Please try again.',
  ]) : super(code: 'AUTH_TIMEOUT');
}

class AuthRateLimitException extends AppException {
  const AuthRateLimitException([
    super.message = 'Too many attempts. Please wait before requesting another OTP.',
  ]) : super(code: 'AUTH_RATE_LIMIT');
}
