import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../auth/data/auth_provider.dart';
import '../../auth/data/user_provider.dart';

class CustomerProfileScreen extends ConsumerStatefulWidget {
  const CustomerProfileScreen({super.key});

  @override
  ConsumerState<CustomerProfileScreen> createState() =>
      _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends ConsumerState<CustomerProfileScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();

  bool _initialized = false;
  bool _isLoading = false;
  bool _isModified = false;

  // Validation State
  String? _nameError;
  String? _emailError;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_validate);
    _emailController.addListener(_validate);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _validate() {
    setState(() {
      _isModified = true;

      // Name Validation
      if (_nameController.text.trim().isEmpty) {
        _nameError = 'Name cannot be empty';
      } else {
        _nameError = null;
      }

      // Email Validation
      final email = _emailController.text.trim();
      final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
      if (email.isNotEmpty && !emailRegex.hasMatch(email)) {
        _emailError = 'Enter a valid email';
      } else {
        _emailError = null;
      }
    });
  }

  bool get _isValid =>
      _nameError == null &&
      _emailError == null &&
      _nameController.text.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final userProfile = ref.watch(userProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/customer-home'),
        ),
      ),
      body: userProfile.when(
        data: (user) {
          if (user == null) return const Center(child: Text('User not found'));

          if (!_initialized) {
            _nameController.text = user['name'] ?? '';
            _emailController.text = user['email'] ?? '';
            // Reset modified flag after initial population
            Future.microtask(() {
              if (mounted) setState(() => _isModified = false);
            });
            _initialized = true;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const CircleAvatar(
                  radius: 40,
                  backgroundColor: AppTheme.primaryColor,
                  child: Icon(Icons.person, size: 40, color: Colors.white),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    user['phoneNumber'] ?? 'N/A',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                const SizedBox(height: 32),

                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Name',
                    border: const OutlineInputBorder(),
                    errorText: _isModified ? _nameError : null,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    border: const OutlineInputBorder(),
                    errorText: _isModified ? _emailError : null,
                  ),
                ),

                const SizedBox(height: 32),

                ElevatedButton(
                  onPressed: (_isLoading || !_isValid || !_isModified)
                      ? null
                      : () => _updateProfile(user['uid']),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                    disabledForegroundColor: Colors.grey.shade600,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Save Changes'),
                ),

                const SizedBox(height: 24),

                OutlinedButton.icon(
                  onPressed: () {
                    context.push('/reset-pin');
                  },
                  icon: const Icon(Icons.lock_reset),
                  label: const Text('Reset PIN'),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => _logout(context, ref),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  icon: const Icon(Icons.logout),
                  label: const Text('Logout'),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Future<void> _updateProfile(String? uid) async {
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: User ID is missing.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final func = FirebaseFunctions.instance.httpsCallable('updateProfile');
      await func.call({
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
      });

      // Invalidate provider to refresh data
      ref.invalidate(userProfileProvider);

      if (mounted) {
        setState(() => _isModified = false); // Scan as saved
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile Updated Successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating profile: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Logout'),
            content: const Text('Are you sure you want to logout?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Logout'),
              ),
            ],
          ),
        ) ??
        false;

    if (confirmed) {
      await ref.read(authRepositoryProvider).signOut();
      if (context.mounted) context.go('/login');
    }
  }
}
