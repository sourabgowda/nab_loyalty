import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/global_config_provider.dart';

import '../../../../core/utils/error_handler.dart';

class GlobalConfigScreen extends ConsumerStatefulWidget {
  const GlobalConfigScreen({super.key});

  @override
  ConsumerState<GlobalConfigScreen> createState() => _GlobalConfigScreenState();
}

class _GlobalConfigScreenState extends ConsumerState<GlobalConfigScreen> {
  final _pointValueController = TextEditingController();
  final _creditPercentController = TextEditingController();
  final _minRedeemController = TextEditingController();
  final _maxFuelController = TextEditingController();
  final List<String> _fuelTypes = [];
  final _newFuelTypeController = TextEditingController();

  bool _isLoading = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    // Listen to changes to update button state
    _pointValueController.addListener(() => setState(() {}));
    _creditPercentController.addListener(() => setState(() {}));
    _minRedeemController.addListener(() => setState(() {}));
    _maxFuelController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _pointValueController.dispose();
    _creditPercentController.dispose();
    _minRedeemController.dispose();
    _maxFuelController.dispose();
    _newFuelTypeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(globalConfigProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Global Configuration'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/admin-home'),
        ),
      ),
      body: configAsync.when(
        data: (config) {
          if (!_initialized) {
            if (config != null) {
              _pointValueController.text = (config['pointValue'] ?? 1.0)
                  .toString();
              _creditPercentController.text =
                  (config['creditPercentage'] ?? 2.0).toString();
              _minRedeemController.text = (config['minRedeemPoints'] ?? 100)
                  .toString();
              _maxFuelController.text = (config['maxFuelAmount'] ?? 10000)
                  .toString();
              if (config['fuelTypes'] != null) {
                _fuelTypes.addAll(List<String>.from(config['fuelTypes']));
              } else {
                // Default if empty
                if (_fuelTypes.isEmpty) {
                  _fuelTypes.addAll(['Gas', 'Petrol', 'Diesel']);
                }
              }
            }
            _initialized = true;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildNumberField(
                  _pointValueController,
                  'Point Value (e.g. 1.0 = 1₹/pt)',
                ),
                const SizedBox(height: 16),
                _buildNumberField(
                  _creditPercentController,
                  'Credit Percentage (%)',
                ),
                const SizedBox(height: 16),
                _buildNumberField(_minRedeemController, 'Min Redeem Points'),
                const SizedBox(height: 16),
                _buildNumberField(
                  _maxFuelController,
                  'Max Fuel Amount (Safety Cap)',
                ),

                const SizedBox(height: 24),
                Text(
                  'Fuel Types',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: _fuelTypes
                      .map(
                        (type) => Chip(
                          label: Text(type),
                          deleteIcon: const Icon(Icons.close, size: 18),
                          onDeleted: () =>
                              setState(() => _fuelTypes.remove(type)),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _newFuelTypeController,
                        decoration: const InputDecoration(
                          labelText: 'Add Fuel Type',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle, color: Colors.green),
                      onPressed: _addFuelType,
                    ),
                  ],
                ),

                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: (_isLoading || !_isValid) ? null : _confirmSave,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Save Configuration'),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) =>
            Center(child: Text(ErrorHandler.getUserFriendlyMessage(err))),
      ),
    );
  }

  Widget _buildNumberField(TextEditingController controller, String label) {
    bool isInvalid =
        controller.text.isNotEmpty && double.tryParse(controller.text) == null;
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        errorText: isInvalid ? 'Invalid number' : null,
      ),
    );
  }

  void _addFuelType() {
    final val = _newFuelTypeController.text.trim();
    if (val.isNotEmpty && !_fuelTypes.contains(val)) {
      setState(() {
        _fuelTypes.add(val);
        _newFuelTypeController.clear();
      });
    }
  }

  bool get _isValid {
    return _pointValueController.text.isNotEmpty &&
        _creditPercentController.text.isNotEmpty &&
        _minRedeemController.text.isNotEmpty &&
        _maxFuelController.text.isNotEmpty &&
        double.tryParse(_pointValueController.text) != null &&
        double.tryParse(_creditPercentController.text) != null &&
        double.tryParse(_minRedeemController.text) != null &&
        double.tryParse(_maxFuelController.text) != null;
  }

  Future<void> _confirmSave() async {
    if (!_isValid) return;

    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Confirm Configuration Change'),
            content: const Text(
              'Changing these values affects logical calculations globally immediately. Are you sure?',
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

    if (confirmed) _save();
  }

  Future<void> _save() async {
    setState(() => _isLoading = true);
    try {
      await ref
          .read(adminConfigActionsProvider)
          .updateConfig(
            pointValue: double.parse(_pointValueController.text),
            creditPercentage: double.parse(_creditPercentController.text),
            minRedeemPoints: double.parse(_minRedeemController.text),
            maxFuelAmount: double.parse(_maxFuelController.text),
            fuelTypes: _fuelTypes,
          );

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Configuration saved.')));
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showError(context, e);
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }
}
