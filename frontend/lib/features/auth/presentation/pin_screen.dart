import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/pin_pad.dart';

enum PinMode { set, verify }

class PinScreen extends ConsumerStatefulWidget {
  final PinMode mode;
  const PinScreen({super.key, required this.mode});

  @override
  ConsumerState<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends ConsumerState<PinScreen> {
  String _pin = "";
  bool _isLoading = false;

  void _onDigit(String digit) {
    if (_pin.length < 4) {
      setState(() => _pin += digit);
      // Auto-submit removed per instructions
    }
  }

  void _onDelete() {
    if (_pin.isNotEmpty) {
      setState(() => _pin = _pin.substring(0, _pin.length - 1));
    }
  }

  Future<void> _submit() async {
    if (_pin.length != 4) return;

    setState(() => _isLoading = true);

    try {
      if (widget.mode == PinMode.set) {
        await ref.read(authRepositoryProvider).setPin(_pin);
        if (mounted)
          context.go('/'); // Router will redirect to correct home based on role
      } else {
        final success = await ref.read(authRepositoryProvider).verifyPin(_pin);
        if (success) {
          ref.read(pinSessionProvider.notifier).verified();
          // Router handles redirection based on state, but we might need to nudge it or wait
          // Actually if we just set verified, the router refresh listener should pick it up.
          // Or we can explicitly navigate to home.
        }
      }
    } catch (e) {
      if (mounted) _showError(e.toString());
      if (mounted) setState(() => _pin = ""); // Clear on error
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _forgotPin() async {
    // Sign out to force re-authentication
    await ref.read(authRepositoryProvider).signOut();
    // Redirect to login with intent to reset PIN
    if (mounted) {
      context.go(
        Uri(
          path: '/login',
          queryParameters: {'redirect': '/reset-pin'},
        ).toString(),
      );
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppTheme.errorColor),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),
                      const Icon(
                        Icons.lock_outline,
                        size: 60,
                        color: AppTheme.secondaryColor,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        widget.mode == PinMode.set
                            ? "Set a 4-digit PIN"
                            : "Enter PIN",
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 40),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(4, (index) {
                          final filled = index < _pin.length;
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 12),
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: filled
                                  ? AppTheme.secondaryColor
                                  : Colors.white24,
                              shape: BoxShape.circle,
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 40), // Spacer from dots
                      PinPad(
                        onDigit: _onDigit,
                        onDelete: _onDelete,
                        onSubmit: _submit,
                        canSubmit: _pin.length == 4 && !_isLoading,
                      ),

                      if (widget.mode == PinMode.verify)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: TextButton(
                            onPressed: _forgotPin,
                            child: const Text(
                              "Forgot PIN?",
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
