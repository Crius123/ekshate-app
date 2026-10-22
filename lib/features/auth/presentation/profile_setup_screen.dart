import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/errors/app_exception.dart';
import '../domain/delivery_address.dart';
import 'widgets/auth_error_banner.dart';
import 'auth_controller.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _nameController = TextEditingController();
  final _addressLineController = TextEditingController();
  final _areaController = TextEditingController();
  final _cityController = TextEditingController(text: 'Dhaka');

  bool _isLoading = false;
  String? _errorMessage;

  static const List<String> _popularAreas = [
    'Dhanmondi',
    'Gulshan',
    'Banani',
    'Uttara',
    'Mirpur',
    'Mohammadpur',
    'Bashundhara R/A',
  ];

  @override
  void initState() {
    super.initState();
    // Pre-populate if current user already has existing partial details
    final currentUser = ref.read(authStateProvider).value;
    if (currentUser != null) {
      if (currentUser.displayName != null && currentUser.displayName!.isNotEmpty) {
        _nameController.text = currentUser.displayName!;
      }
      if (currentUser.deliveryAddress != null && currentUser.deliveryAddress!.isNotEmpty) {
        final parsed = DeliveryAddress.parse(currentUser.deliveryAddress);
        if (parsed.addressLine.isNotEmpty) {
          _addressLineController.text = parsed.addressLine;
        }
        if (parsed.area.isNotEmpty) {
          _areaController.text = parsed.area;
        }
        if (parsed.city.isNotEmpty) {
          _cityController.text = parsed.city;
        }
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressLineController.dispose();
    _areaController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final name = _nameController.text.trim();
    final addressLine = _addressLineController.text.trim();
    final area = _areaController.text.trim();
    final city = _cityController.text.trim();

    if (name.isEmpty || name.length < 2) {
      setState(() {
        _errorMessage = 'Full name is required (at least 2 characters).';
      });
      return;
    }

    if (addressLine.isEmpty) {
      setState(() {
        _errorMessage = 'Street address / house number is required.';
      });
      return;
    }

    if (area.isEmpty) {
      setState(() {
        _errorMessage = 'Area or neighborhood is required.';
      });
      return;
    }

    if (city.isEmpty) {
      setState(() {
        _errorMessage = 'City is required.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref.read(authStateProvider.notifier).completeProfile(
            displayName: name,
            address: DeliveryAddress(
              addressLine: addressLine,
              area: area,
              city: city,
            ),
          );

      if (!mounted) return;

      ShadToaster.of(context).show(
        const ShadToast(
          title: Text('Profile Completed'),
          description: Text('Your delivery profile has been configured successfully.'),
        ),
      );

      context.go(RoutePaths.dailySale);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e is AppException ? e.message : 'Failed to save profile. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ShadCard(
              title: Text('Delivery Profile', style: theme.textTheme.h3),
              description: Padding(
                padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
                child: Text(
                  'Please provide your full name and delivery address to complete your community bulk purchasing profile.',
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
                      onRetry: _errorMessage!.contains('timed out') ? _handleSubmit : null,
                    ),

                  // Full Name
                  Text('Full Name', style: theme.textTheme.small),
                  const SizedBox(height: 6),
                  ShadInput(
                    controller: _nameController,
                    placeholder: const Text('e.g. Rahim Ahmed'),
                  ),
                  const SizedBox(height: 16),

                  // Street / House / Flat
                  Text('Street / House / Flat', style: theme.textTheme.small),
                  const SizedBox(height: 6),
                  ShadInput(
                    controller: _addressLineController,
                    placeholder: const Text('e.g. House 12, Road 5, Flat 4B'),
                  ),
                  const SizedBox(height: 16),

                  // Area / Neighborhood
                  Text('Area / Neighborhood', style: theme.textTheme.small),
                  const SizedBox(height: 6),
                  ShadInput(
                    controller: _areaController,
                    placeholder: const Text('e.g. Dhanmondi'),
                  ),
                  const SizedBox(height: 8),

                  // Quick area suggestions
                  Wrap(
                    spacing: 6.0,
                    runSpacing: 6.0,
                    children: _popularAreas.map((area) {
                      final isSelected = _areaController.text.trim() == area;
                      return InkWell(
                        onTap: () {
                          setState(() {
                            _areaController.text = area;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? theme.colorScheme.primary.withAlpha(40)
                                : theme.colorScheme.muted.withAlpha(30),
                            borderRadius: BorderRadius.circular(12.0),
                            border: Border.all(
                              color: isSelected
                                  ? theme.colorScheme.primary
                                  : Colors.transparent,
                            ),
                          ),
                          child: Text(
                            area,
                            style: theme.textTheme.small.copyWith(
                              fontSize: 12,
                              color: isSelected
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.mutedForeground,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // City
                  Text('City', style: theme.textTheme.small),
                  const SizedBox(height: 6),
                  ShadInput(
                    controller: _cityController,
                    placeholder: const Text('e.g. Dhaka'),
                  ),
                  const SizedBox(height: 24),

                  // Submit Button
                  ShadButton(
                    enabled: !_isLoading,
                    onPressed: _handleSubmit,
                    child: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save & Continue'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
