import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/bunk_management_provider.dart';
import '../../data/global_config_provider.dart';

import '../../../../core/utils/error_handler.dart';
import '../../data/user_management_provider.dart';

class BunkDetailScreen extends ConsumerStatefulWidget {
  final String bunkId;
  const BunkDetailScreen({super.key, required this.bunkId});

  @override
  ConsumerState<BunkDetailScreen> createState() => _BunkDetailScreenState();
}

class _BunkDetailScreenState extends ConsumerState<BunkDetailScreen> {
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  // final _managerIdController = TextEditingController(); // REMOVED
  final _managerSearchController =
      TextEditingController(); // For the search field itself

  List<Map<String, dynamic>> _assignedManagers = [];
  final List<String> _selectedFuelTypes = ['Gas']; // Default to Gas

  bool _active = true;
  bool _isLoading = false;
  bool _initialized = false;
  bool _managersPopulated = false; // New flag for initial manager population

  // Validation
  bool _isValid = false;
  String? _nameError;
  String? _locationError;
  String? _fuelError;

  bool get _isNew => widget.bunkId == 'new';

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_validate);
    _locationController.addListener(_validate);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _managerSearchController.dispose();
    super.dispose();
  }

  void _validate() {
    bool valid = true;
    String? nameErr;
    String? locErr;
    String? fuelErr;

    if (_nameController.text.trim().isEmpty) {
      nameErr = "Name required";
      valid = false;
    }

    if (_locationController.text.trim().isEmpty) {
      locErr = "Location required";
      valid = false;
    }

    if (mounted) {
      setState(() {
        _nameError = nameErr;
        _locationError = locErr;
        _fuelError = fuelErr;
        _isValid = valid;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bunkAsync = ref.watch(adminBunkDetailProvider(widget.bunkId));
    final configAsync = ref.watch(globalConfigProvider);
    // Fetch available managers. Pass current bunk ID to exclude it from "assigned" check (allow keeping current managers).
    final availableManagersAsync = ref.watch(
      availableManagersProvider(_isNew ? null : widget.bunkId),
    );

    final fuelOptions = configAsync.value?['fuelTypes'] != null
        ? List<String>.from(configAsync.value!['fuelTypes'])
        : ['Gas'];

    return Scaffold(
      appBar: AppBar(title: Text(_isNew ? 'New Bunk' : 'Edit Bunk')),
      body: bunkAsync.when(
        data: (bunk) {
          if (!_isNew && bunk == null) {
            return const Center(child: Text('Bunk not found.'));
          }

          if (!_initialized) {
            if (bunk != null) {
              _nameController.text = bunk['name'] ?? '';
              _locationController.text = bunk['location'] ?? '';
              _active = bunk['active'] != false;
              if (bunk['fuelTypes'] != null) {
                _selectedFuelTypes.clear(); // Clear default Gas if editing
                _selectedFuelTypes.addAll(List<String>.from(bunk['fuelTypes']));
              }
            }
            // Initial Load of Managers is handled inside the listener below or manually if we have the list
            // However, `bunk` here only has managerIds (strings). We need the full objects to display names.
            // But `availableManagersAsync` has ALL managers. We can find them there.
            // We'll defer population until availableManagersAsync is ready.

            _initialized = true;
            // Trigger initial validation after data load
            Future.microtask(() => _validate());
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!_isNew) ...[
                  // Improved ID Display
                  InkWell(
                    onTap: () {
                      // Select all text if possible, or just copy
                      // For simplicity just using SelectableText approach or ReadOnly Input
                    },
                    child: TextField(
                      controller: TextEditingController(text: widget.bunkId),
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Bunk UID',
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.copy),
                          onPressed: () {
                            Clipboard.setData(
                              ClipboardData(text: widget.bunkId),
                            ).then((_) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Bunk ID copied to clipboard"),
                                ),
                              );
                            });
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Bunk Name',
                    border: const OutlineInputBorder(),
                    errorText: _nameError,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _locationController,
                  decoration: InputDecoration(
                    labelText: 'Location / Address',
                    border: const OutlineInputBorder(),
                    errorText: _locationError,
                  ),
                ),
                const SizedBox(height: 16),

                // Manager Selection UI
                availableManagersAsync.when(
                  data: (managers) {
                    // Populate _assignedManagers if empty and bunk has data
                    if (_assignedManagers.isEmpty &&
                        bunk != null &&
                        !_managersPopulated) {
                      final List<String> currentIds = [];
                      if (bunk['managerIds'] != null) {
                        currentIds.addAll(
                          List<String>.from(bunk['managerIds']),
                        );
                      } else if (bunk['managerId'] != null) {
                        // Handle legacy single managerId
                        currentIds.add(bunk['managerId']);
                      }

                      // We need to look up these IDs in 'managers'.
                      // Note: 'managers' from provider only returns AVAILABLE ones (not assigned to OTHER bunks).
                      // Since we passed this bunkId to the provider, it should include current managers of THIS bunk.
                      // So finding them in 'managers' list is safe.

                      // BUT there's a catch: we need to ensure we run this only once or carefully.
                      // Since build runs often, we shouldn't overwrite if user modified it.
                      // But _assignedManagers is state.
                      // Fix: We rely on `_initialized` flag, but we need managers loaded first.
                      // Let's do a one-time population logic here.
                    }

                    // Better approach for initial population:
                    // Do it once when both data are available.
                    // Or keep a separate flag `_managersLoaded`.

                    if (_assignedManagers.isEmpty &&
                        bunk != null &&
                        !_managersPopulated) {
                      final List<String> currentIds = [];
                      if (bunk['managerIds'] != null) {
                        currentIds.addAll(
                          List<String>.from(bunk['managerIds']),
                        );
                      } else if (bunk['managerId'] != null) {
                        currentIds.add(bunk['managerId']);
                      }

                      // We also need to fetch full manager details if they are not in the "available" list
                      // (e.g. if something is weird). But usually they should be there.
                      // Wait, fetching full details might require a separate call if the provider filters them out?
                      // The provider includes "managers of THIS bunk" if we passed bunkId. So they should be in `managers`.

                      final preExisting = managers
                          .where((m) => currentIds.contains(m['uid']))
                          .toList();
                      _assignedManagers.addAll(preExisting);
                      // Mark as populated so we don't reset inputs
                      _managersPopulated = true;
                      // Force rebuild to show chips
                      WidgetsBinding.instance.addPostFrameCallback(
                        (_) => setState(() {}),
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Assigned Managers:",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8.0,
                          runSpacing: 4.0,
                          children: _assignedManagers.map((manager) {
                            return Chip(
                              avatar: CircleAvatar(
                                child: Text(
                                  (manager['name'] ?? 'U')[0].toUpperCase(),
                                ),
                              ),
                              label: Text(
                                "${manager['name']} (${manager['phoneNumber']})",
                              ),
                              deleteIcon: const Icon(Icons.close),
                              onDeleted: () async {
                                // Confirmation Dialog
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text("Unassign Manager?"),
                                    content: Text(
                                      "Are you sure you want to remove ${manager['name']} from this bunk?",
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: const Text("Cancel"),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        child: const Text(
                                          "Remove",
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirm == true) {
                                  setState(() {
                                    _assignedManagers.removeWhere(
                                      (m) => m['uid'] == manager['uid'],
                                    );
                                  });
                                }
                              },
                            );
                          }).toList(),
                        ),
                        if (_assignedManagers.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text(
                              "No managers assigned.",
                              style: TextStyle(
                                fontStyle: FontStyle.italic,
                                color: Colors.grey,
                              ),
                            ),
                          ),

                        const SizedBox(height: 16),

                        Autocomplete<Map<String, dynamic>>(
                          optionsBuilder: (TextEditingValue textEditingValue) {
                            if (textEditingValue.text == '') {
                              return const Iterable<
                                Map<String, dynamic>
                              >.empty();
                            }
                            // Filter out already assigned ones from the options
                            final assignedIds = _assignedManagers
                                .map((m) => m['uid'])
                                .toSet();

                            return managers.where((
                              Map<String, dynamic> option,
                            ) {
                              if (assignedIds.contains(option['uid']))
                                return false; // Already assigned

                              final name = (option['name'] ?? '').toLowerCase();
                              final phone = (option['phoneNumber'] ?? '')
                                  .toLowerCase();
                              final query = textEditingValue.text.toLowerCase();
                              return name.contains(query) ||
                                  phone.contains(query);
                            });
                          },
                          displayStringForOption: (option) =>
                              "${option['name']} (${option['phoneNumber']})",
                          fieldViewBuilder:
                              (
                                context,
                                textEditingController,
                                focusNode,
                                onFieldSubmitted,
                              ) {
                                return TextField(
                                  controller: textEditingController,
                                  focusNode: focusNode,
                                  decoration: const InputDecoration(
                                    labelText: 'Search & Add Manager',
                                    helperText: 'Type Name or Phone to add',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.person_add),
                                  ),
                                );
                              },
                          onSelected: (Map<String, dynamic> selection) {
                            setState(() {
                              _assignedManagers.add(selection);
                              // Clear the search field? Handled by Autocomplete usually but check controller availability
                              // Actually Autocomplete doesn't expose controller easily in onSelected unless we manage it.
                              // But selecting usually fills the text. We want to clear it to allow adding another.
                              // We need a way to clear the internal, or use a key.
                              // Actually we can't easily clear the default text field of Autocomplete without the controller passed in fieldViewBuilder.
                              // But we aren't storing that controller.
                              // Let's try forcing a rebuild or managing the controller if we can.
                              // Simplest is to let user clear it or just type over.
                              // But "Add" feels like it should reset.
                              // Let's ignore for now to keep it simple, or use a key to reset.
                            });
                            // Hack to clear: Rebuild might not clear the text field internal state.
                            // Actually we can pass a controller to fieldViewBuilder!
                            // We need to store it.
                            // Refactoring `fieldViewBuilder` to use `_managerSearchController` wouldn't work because `state` owns it.
                            // We'll leave it as is for now.
                          },
                        ),
                      ],
                    );
                  },
                  loading: () => const LinearProgressIndicator(),
                  error: (e, s) => Text("Error loading managers: $e"),
                ),

                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Active Bunk'),
                  value: _active,
                  onChanged: (val) => setState(() => _active = val),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Allowed Fuel Types:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                ...fuelOptions.map((type) {
                  return CheckboxListTile(
                    title: Text(type),
                    value: _selectedFuelTypes.contains(type),
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedFuelTypes.add(type);
                        } else {
                          _selectedFuelTypes.remove(type);
                        }
                        _validate();
                      });
                    },
                  );
                }),
                if (_fuelError != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Text(
                      _fuelError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 12,
                      ),
                    ),
                  ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: (_isLoading || !_isValid)
                      ? null
                      : () => _save(bunk ?? {}),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                    disabledForegroundColor: Colors.grey.shade600,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(_isNew ? 'Create Bunk' : 'Save Changes'),
                ),
                if (!_isNew) ...[
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: _isLoading ? null : () => _delete(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Delete Bunk'),
                  ),
                ],
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Future<void> _save(Map<String, dynamic> originalBunk) async {
    setState(() => _isLoading = true);
    try {
      final updates = <String, dynamic>{};

      // Calculate Diff
      if (_nameController.text.trim() != (originalBunk['name'] ?? '')) {
        updates['name'] = _nameController.text.trim();
      }
      if (_locationController.text.trim() != (originalBunk['location'] ?? '')) {
        updates['location'] = _locationController.text.trim();
      }

      // Manager IDs Diff
      // Normalized old IDs
      final List<String> oldManagerIds = [];
      if (originalBunk['managerIds'] != null) {
        oldManagerIds.addAll(List<String>.from(originalBunk['managerIds']));
      } else if (originalBunk['managerId'] != null) {
        oldManagerIds.add(originalBunk['managerId']);
      }
      oldManagerIds.sort();

      // New IDs
      final List<String> newManagerIds = _assignedManagers
          .map((m) => m['uid'] as String)
          .toList();
      newManagerIds.sort();

      if (oldManagerIds.join(',') != newManagerIds.join(',')) {
        updates['managerIds'] = newManagerIds;
        // explicit null for legacy field if we are updating (optional but cleaner)
        if (originalBunk['managerId'] != null) {
          updates['managerId'] =
              null; // or FieldValue.delete() if backend supports map decoding of it
          // Backend uses merge: true so sending null usually updates it to null or ignores if undefined.
          // Let's send null.
        }
      }

      if (_active != (originalBunk['active'] != false)) {
        updates['active'] = _active;
      }

      // Deep compare for lists (very basic implementation)
      final oldFuels = List<String>.from(originalBunk['fuelTypes'] ?? []);
      oldFuels.sort();
      final newFuels = List<String>.from(_selectedFuelTypes);
      newFuels.sort();
      if (oldFuels.join(',') != newFuels.join(',')) {
        updates['fuelTypes'] = _selectedFuelTypes;
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

      if (_isNew) {
        await ref
            .read(adminBunkActionsProvider)
            .createBunk(
              name: _nameController.text.trim(),
              location: _locationController.text.trim(),
              managerIds: _assignedManagers
                  .map((m) => m['uid'] as String)
                  .toList(),
              active: _active,
              fuelTypes: _selectedFuelTypes,
            );
      } else {
        await ref
            .read(adminBunkActionsProvider)
            .updateBunk(widget.bunkId, updates);
      }

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Saved successfully.')));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showError(context, e);
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Bunk'),
        content: const Text(
          'Are you sure you want to delete this bunk? This action cannot be undone if not properly backed up. Ensure no critical transactions are linked if system enforces integrity.',
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
      setState(() => _isLoading = true);
      try {
        await ref.read(adminBunkActionsProvider).deleteBunk(widget.bunkId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bunk deleted successfully.')),
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
