import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import '../data/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_handler.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isValid = false;

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_validate);
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _validate() {
    final phone = _phoneController.text.trim();
    // Validate 10 digits
    final isValid = RegExp(r'^[0-9]{10}$').hasMatch(phone);
    if (_isValid != isValid) {
      setState(() => _isValid = isValid);
    }
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final phone =
          "+91${_phoneController.text.trim()}"; // Hardcoded India code for now
      ref
          .read(authControllerProvider.notifier)
          .sendOtp(
            phone,
            onCodeSent: () {
              final redirect = GoRouterState.of(
                context,
              ).uri.queryParameters['redirect'];
              if (redirect != null) {
                context.push(
                  Uri(
                    path: '/otp',
                    queryParameters: {'redirect': redirect},
                  ).toString(),
                );
              } else {
                context.push('/otp');
              }
            },
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    final isLoading = state is AsyncLoading;

    ref.listen(authControllerProvider, (previous, next) {
      if (next is AsyncError) {
        ErrorHandler.showError(context, next.error);
      }
    });

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.local_gas_station,
                    size: 80,
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(height: 32),
                  Text(
                    "Bunk Loyalty",
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(fontSize: 18),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    maxLength: 10,
                    decoration: const InputDecoration(
                      labelText: "Phone Number",
                      prefixText: "+91 ",
                      prefixIcon: Icon(Icons.phone),
                      counterText: "", // Hide character counter
                    ),
                    validator: (value) {
                      if (value == null ||
                          !RegExp(r'^[0-9]{10}$').hasMatch(value)) {
                        return "Enter a valid 10-digit number";
                      }
                      return null;
                    },
                    enabled: !isLoading,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: (isLoading || !_isValid) ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      disabledBackgroundColor: Colors.grey.shade300,
                      disabledForegroundColor: Colors.grey.shade600,
                    ),
                    child: isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text("Continue"),
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
