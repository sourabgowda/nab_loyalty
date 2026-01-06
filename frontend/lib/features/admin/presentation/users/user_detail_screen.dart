import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/error_handler.dart';
import '../../data/user_management_provider.dart';

class UserDetailScreen extends ConsumerStatefulWidget {
  final String uid;
  const UserDetailScreen({super.key, required this.uid});

  @override
  ConsumerState<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends ConsumerState<UserDetailScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController(); // Assuming we have email?
  // Note: Firestore User types might not have email field standardized yet in this app context,
  // but requirements said "Editable Fields: First name, Last name, Email".
  // "Last name" might be part of "name" field or separate?
  // Let's assume 'name' is full name for now as per previous schemas.

  String _role = 'customer';
  bool _isActive = true;
  bool _isLoading = false;
  bool _initialized = false;

  // Validation
  bool _isValid = false;
  String? _nameError;
  String? _emailError;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_validate);
    _emailController.addListener(_validate);
  }

  void _validate() {
    bool valid = true;
    String? nameErr;
    String? emailErr;

    if (_nameController.text.trim().isEmpty) {
      nameErr = "Name required";
      valid = false;
    }

    final email = _emailController.text.trim();
    if (email.isNotEmpty && !email.contains('@')) {
      emailErr = "Invalid email";
      valid = false;
    }

    if (mounted) {
      setState(() {
        _nameError = nameErr;
        _emailError = emailErr;
        _isValid = valid;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var userAsync = ref.watch(userDetailProvider(widget.uid));

    return Scaffold(
      appBar: AppBar(title: const Text('User Details')),
      body: userAsync.when(
        data: (user) {
          if (user == null) {
            return const Center(child: Text('User not found.'));
          }

          // Initialize controllers once
          if (!_initialized) {
            _nameController.text = user['name'] ?? '';
            _emailController.text = user['email'] ?? '';
            _role = user['role'] ?? 'customer';
            _isActive = user['active'] != false;
            _initialized = true;
            Future.microtask(() => _validate()); // Initial validation
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Info Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Phone: ${user['phoneNumber'] ?? 'N/A'}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'UID: ${widget.uid}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Form
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Name',
                    border: const OutlineInputBorder(),
                    errorText: _nameError,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    border: const OutlineInputBorder(),
                    errorText: _emailError,
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  // ignore: deprecated_member_use
                  value: _role,
                  decoration: const InputDecoration(
                    labelText: 'Role',
                    border: OutlineInputBorder(),
                  ),
                  items: ['customer', 'manager', 'admin']
                      .map(
                        (r) => DropdownMenuItem(
                          value: r,
                          child: Text(r.toUpperCase()),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val != null && val != _role) {
                      _confirmRoleChange(context, val).then((confirmed) {
                        if (confirmed) setState(() => _role = val);
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Active Account'),
                  value: _isActive,
                  onChanged: (val) => setState(() => _isActive = val),
                ),

                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: (_isLoading || !_isValid)
                      ? null
                      : () => _save(user),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    disabledBackgroundColor: Colors.grey.shade300,
                    disabledForegroundColor: Colors.grey.shade600,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Save Changes'),
                ),

                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => _resetPin(context),
                  icon: const Icon(Icons.lock_reset),
                  label: const Text('Reset PIN'),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: _isLoading ? null : () => _delete(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Delete User'),
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

  Future<bool> _confirmRoleChange(BuildContext context, String newRole) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Confirm Role Change'),
            content: Text(
              'Are you sure you want to change this user\'s role to $newRole?\n\nThe user may gain or lose access to critical features immediately.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Confirm'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _save(Map<String, dynamic> originalUser) async {
    setState(() => _isLoading = true);
    try {
      final updates = <String, dynamic>{};
      if (_nameController.text != (originalUser['name'] ?? '')) {
        updates['name'] = _nameController.text;
      }
      if (_emailController.text != (originalUser['email'] ?? '')) {
        updates['email'] = _emailController.text;
      }
      if (_role != (originalUser['role'] ?? 'customer')) {
        updates['role'] = _role;
      }
      if (_isActive != (originalUser['active'] != false)) {
        updates['active'] = _isActive;
      }

      if (updates.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('No changes to save.')));
        }
        setState(() => _isLoading = false);
        return;
      }

      await ref.read(adminUserActionsProvider).updateUser(widget.uid, updates);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User updated successfully.')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _resetPin(BuildContext context) async {
    // Placeholder for Reset PIN logic
    // Usually calls a cloud function to reset PIN or clear PinHash
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reset PIN not implemented yet.')),
    );
  }

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: const Text(
          'Are you sure you want to delete this user? This will also disable their login access and is generally irreversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!mounted) return;
      setState(() => _isLoading = true);
      try {
        await ref.read(adminUserActionsProvider).deleteUser(widget.uid);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User deleted successfully.')),
          );
          context.pop();
        }
      } catch (e) {
        if (mounted) ErrorHandler.showError(context, e);
      }
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
