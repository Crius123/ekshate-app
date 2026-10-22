import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/errors/app_exception.dart';
import '../domain/phone_number_validator.dart';
import 'widgets/auth_error_banner.dart';
import 'auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  bool _otpSent = false;
  bool _isLoading = false;
  String? _errorMessage;
  String? _canonicalPhone;

  // Countdown timer for SMS OTP resend (starts at 60 seconds)
  Timer? _countdownTimer;
  int _secondsRemaining = 60;

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    setState(() {
      _secondsRemaining = 60;
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _handleSendOtp() async {
    final rawPhone = _phoneController.text.trim();

    if (!PhoneNumberValidator.isValid(rawPhone)) {
      setState(() {
        _errorMessage = 'Please enter a valid Bangladeshi mobile number (e.g. 017XXXXXXXX).';
      });
      return;
    }

    final canonical = PhoneNumberValidator.toCanonical(rawPhone);

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _canonicalPhone = canonical;
    });

    try {
      await ref.read(authStateProvider.notifier).sendOtp(canonical);
      if (!mounted) return;
      setState(() {
        _otpSent = true;
        _isLoading = false;
        _errorMessage = null;
      });
      _startCountdown();

      ShadToaster.of(context).show(
        const ShadToast(
          title: Text('OTP Sent'),
          description: Text('A 6-digit verification code has been sent via SMS.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e is AppException ? e.message : 'Failed to send OTP. Please try again.';
      });
    }
  }

  Future<void> _handleResendOtp() async {
    if (_canonicalPhone == null || _secondsRemaining > 0) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref.read(authStateProvider.notifier).resendOtp(_canonicalPhone!);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _otpController.clear();
      });
      _startCountdown();

      ShadToaster.of(context).show(
        const ShadToast(
          title: Text('OTP Resent'),
          description: Text('A fresh 6-digit verification code has been sent via SMS.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e is AppException ? e.message : 'Failed to resend code. Please try again.';
      });
    }
  }

  Future<void> _handleVerifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      setState(() {
        _errorMessage = 'Please enter a valid 6-digit SMS verification code.';
      });
      return;
    }

    if (_canonicalPhone == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await ref.read(authStateProvider.notifier).verifyOtp(
            phoneNumber: _canonicalPhone!,
            otp: otp,
          );

      if (!mounted) return;

      if (!user.isProfileComplete) {
        context.go(RoutePaths.profileSetup);
      } else {
        context.go(RoutePaths.dailySale);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e is AppException ? e.message : 'Verification failed. Please try again.';
      });
    }
  }

  void _handleChangeNumber() {
    _countdownTimer?.cancel();
    setState(() {
      _otpSent = false;
      _isLoading = false;
      _errorMessage = null;
      _otpController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: ShadCard(
              title: Text('Welcome to Ekshate', style: theme.textTheme.h3),
              description: Padding(
                padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
                child: Text(
                  _otpSent
                      ? 'Enter the 6-digit verification code sent to ${PhoneNumberValidator.formatDisplay(_canonicalPhone ?? _phoneController.text)}'
                      : 'Community bulk purchasing platform with guaranteed wholesale prices.',
                  style: theme.textTheme.muted,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Error boundary feedback banner
                  if (_errorMessage != null)
                    AuthErrorBanner(
                      message: _errorMessage!,
                      onRetry: _errorMessage!.contains('timed out')
                          ? (_otpSent ? _handleVerifyOtp : _handleSendOtp)
                          : null,
                    ),

                  if (!_otpSent) ...[
                    // Phone Number Input with Bangladeshi Prefix & Phone Masking
                    ShadInput(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      placeholder: const Text('01711-000001'),
                      inputFormatters: [
                        BdPhoneInputFormatter(),
                      ],
                      leading: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8.0),
                        child: Text(
                          '+88',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ShadButton(
                      enabled: !_isLoading,
                      onPressed: _handleSendOtp,
                      child: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Send Verification Code'),
                    ),
                  ] else ...[
                    // Interactive OTP Input
                    ShadInput(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      placeholder: const Text('Enter 6-digit SMS OTP'),
                      maxLength: 6,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Resend countdown timer or active button
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      runSpacing: 4.0,
                      children: [
                        InkWell(
                          onTap: _isLoading ? null : _handleChangeNumber,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                            child: Text(
                              'Change Number',
                              style: theme.textTheme.small.copyWith(
                                color: theme.colorScheme.primary,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                        if (_secondsRemaining > 0)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                            child: Text(
                              'Resend code in ${_secondsRemaining}s',
                              style: theme.textTheme.muted,
                            ),
                          )
                        else
                          InkWell(
                            onTap: _isLoading ? null : _handleResendOtp,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                              child: Text(
                                'Resend Code',
                                style: theme.textTheme.small.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ShadButton(
                      enabled: !_isLoading,
                      onPressed: _handleVerifyOtp,
                      child: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Verify & Continue'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
