import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/error_handler.dart';
import '../../admin/data/global_config_provider.dart';
import '../data/manager_bunk_provider.dart';

class AddFuelScreen extends ConsumerStatefulWidget {
  const AddFuelScreen({super.key});

  @override
  ConsumerState<AddFuelScreen> createState() => _AddFuelScreenState();
}

class _AddFuelScreenState extends ConsumerState<AddFuelScreen> {
  final _amountController = TextEditingController();
  final _redeemPointsController = TextEditingController();
  final _phoneController = TextEditingController();
  final _registerNameController = TextEditingController(); // For registration

  String? _scannedUid;
  String? _customerName; // Display Name
  String? _customerPhone; // Display Phone

  String _transactionType = 'CREDIT'; // CREDIT or REDEEM
  String _selectedFuelType = 'Petrol';
  bool _isLoading = false;
  int _userAvailablePoints = 0;

  // Validation
  bool _isValid = false;
  String? _amountError;
  String? _redeemError;
  String? _phoneError;

  // QR Controller
  final MobileScannerController _scannerController = MobileScannerController();
  bool _isScanning = true; // Toggle between Scan and Manual

  @override
  void initState() {
    super.initState();
    _amountController.addListener(_validate);
    _redeemPointsController.addListener(_validate);
    _phoneController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _amountController.dispose();
    _redeemPointsController.dispose();
    _phoneController.dispose();
    _registerNameController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  void _validate() {
    bool valid = true;
    String? amountErr;
    String? redeemErr;

    // Validate Amount
    final amountText = _amountController.text.trim();
    final amount = double.tryParse(amountText);
    if (amountText.isNotEmpty && (amount == null || amount <= 0)) {
      amountErr = "Enter valid amount";
      valid = false;
    } else if (amountText.isEmpty) {
      valid = false;
    }

    // Validate Redeem
    if (_transactionType == 'REDEEM') {
      final ptsText = _redeemPointsController.text.trim();
      final pts = int.tryParse(ptsText);
      if (ptsText.isNotEmpty) {
        if (pts == null || pts <= 0) {
          redeemErr = "Invalid points";
          valid = false;
        } else if (pts > _userAvailablePoints) {
          redeemErr = "Insufficient points";
          valid = false;
        }
      } else {
        valid = false;
      }
    }

    if (mounted) {
      final config = ref.read(globalConfigProvider).value;
      final maxAmt = (config?['maxFuelAmount'] as num?)?.toDouble() ?? 50000.0;

      if (amountText.isNotEmpty && (amount == null || amount <= 0)) {
        amountErr = "Enter valid amount";
        valid = false;
      } else if (amount != null && amount > maxAmt) {
        amountErr = "Max limit is ₹${maxAmt.toStringAsFixed(0)}";
        valid = false;
      } else if (amountText.isEmpty) {
        valid = false;
      }

      setState(() {
        _amountError = amountErr;
        _redeemError = redeemErr;
        _isValid = valid;
      });
    }
  }

  // --- User Lookup & Registration Logic ---

  Future<void> _verifyPhoneNumber() async {
    final phone = _phoneController.text.trim();
    if (phone.length != 10) {
      setState(() => _phoneError = "Phone number must be 10 digits");
      return;
    }
    setState(() {
      _phoneError = null;
      _isLoading = true;
    });

    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('findUserByPhone')
          .call({'phoneNumber': phone.contains('+91') ? phone : '+91$phone'});

      final data = result.data as Map<String, dynamic>;
      if (data['found'] == true) {
        setState(() {
          _scannedUid = data['uid'];
          _customerName = data['name'];
          _customerPhone = data['phoneNumber'];
          _userAvailablePoints = (data['points'] as num).toInt();
          _isScanning = false; // Switch to transaction view
          _validate();
        });
      } else {
        // Not Found -> Prompt Registration
        if (mounted) _showRegistrationDialog(phone);
      }
    } catch (e) {
      if (mounted) ErrorHandler.showError(context, e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showRegistrationDialog(String phone) {
    _registerNameController.clear();
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('New Customer'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Customer not found. Register them now?'),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _registerNameController,
                    decoration: const InputDecoration(
                      labelText: 'Customer Name',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) => setState(() {}),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: _registerNameController.text.trim().isEmpty
                      ? null
                      : () {
                          Navigator.pop(ctx);
                          _registerCustomer(phone);
                        },
                  child: const Text('Register'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _registerCustomer(String phone) async {
    final name = _registerNameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('registerCustomer')
          .call({
            'phoneNumber': phone.contains('+91') ? phone : '+91$phone',
            'name': name,
          });

      final data = result.data as Map<String, dynamic>;
      if (data['success'] == true) {
        setState(() {
          _scannedUid = data['uid'];
          _customerName = data['name'];
          _customerPhone = data['phoneNumber'];
          _userAvailablePoints = 0;
          _isScanning = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Customer Registered Successfully!')),
        );
      }
    } catch (e) {
      if (mounted) ErrorHandler.showError(context, e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- End Lookup Logic ---

  void _onDetect(BarcodeCapture capture) async {
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty && _scannedUid == null) {
      final String? code = barcodes.first.rawValue;
      if (code != null) {
        _fetchUserProfile(code);
      }
    }
  }

  Future<void> _fetchUserProfile(String uid) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (userDoc.exists && mounted) {
        final data = userDoc.data();
        setState(() {
          _scannedUid = uid;
          _customerName = data?['name'] ?? 'Unknown';
          _customerPhone = data?['phoneNumber'] ?? 'N/A';
          _userAvailablePoints = (data?['points'] as num?)?.toInt() ?? 0;
          _isScanning = false; // Stop scanning
        });
        _validate();
      }
    } catch (e) {
      if (!mounted) return;
      ErrorHandler.showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(globalConfigProvider);
    final bunkAsync = ref.watch(managerBunkProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_scannedUid == null ? 'Customer Entry' : 'Add Transaction'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/manager-home'),
        ),
      ),
      body: configAsync.when(
        data: (config) {
          if (config == null) return const Center(child: Text("Config error"));
          return bunkAsync.when(
            data: (bunk) {
              if (bunk == null) {
                return const Center(child: Text('No Bunk Assigned'));
              }

              // --- 1. User Identification Screen ---
              if (_scannedUid == null) {
                return SingleChildScrollView(
                  child: Column(
                    children: [
                      // Toggle Tabs
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _isScanning = true),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                color: _isScanning
                                    ? AppTheme.primaryColor
                                    : Colors.grey[200],
                                child: Center(
                                  child: Text(
                                    "Scan QR",
                                    style: TextStyle(
                                      color: _isScanning
                                          ? Colors.white
                                          : Colors.black,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _isScanning = false),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                color: !_isScanning
                                    ? AppTheme.primaryColor
                                    : Colors.grey[200],
                                child: Center(
                                  child: Text(
                                    "Phone Number",
                                    style: TextStyle(
                                      color: !_isScanning
                                          ? Colors.white
                                          : Colors.black,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      if (_isScanning)
                        SizedBox(
                          height: 400,
                          child: MobileScanner(
                            controller: _scannerController,
                            onDetect: _onDetect,
                          ),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            children: [
                              TextField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(10),
                                ],
                                decoration: InputDecoration(
                                  labelText: 'Customer Phone',
                                  prefixText: '+91 ',
                                  border: const OutlineInputBorder(),
                                  errorText: _phoneError,
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed:
                                      (_isLoading ||
                                          _phoneController.text.length != 10)
                                      ? null
                                      : _verifyPhoneNumber,
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.all(16),
                                  ),
                                  child: _isLoading
                                      ? const CircularProgressIndicator()
                                      : const Text('VERIFY CUSTOMER'),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              }

              // --- 2. Transaction Screen (User Verified) ---
              final minRedeem =
                  (config['minRedeemPoints'] as num?)?.toInt() ?? 500;
              final canRedeem = _userAvailablePoints >= minRedeem;

              // Filter fuel types based on bunk configuration
              final List<String> availableFuels = bunk['fuelTypes'] != null
                  ? List<String>.from(bunk['fuelTypes'])
                  : [];

              // Valid Selection Logic
              String? validFuelSelection = _selectedFuelType;
              if (!availableFuels.contains(validFuelSelection)) {
                if (availableFuels.isNotEmpty) {
                  validFuelSelection = availableFuels.first;
                  Future.microtask(() {
                    if (mounted && _selectedFuelType != validFuelSelection) {
                      setState(() => _selectedFuelType = validFuelSelection!);
                    }
                  });
                } else {
                  validFuelSelection = null;
                }
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Scanned User Info
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _customerName ?? 'Customer',
                                style: TextStyle(
                                  color: Colors.green[900],
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Text(() {
                            final text = _customerPhone ?? '';
                            String raw = text.replaceAll('+91', '').trim();
                            if (raw.length < 5) return text;
                            String first2 = raw.substring(0, 2);
                            String last3 = raw.substring(raw.length - 3);
                            return '+91 $first2 ***** $last3';
                          }(), style: const TextStyle(color: Colors.grey)),
                          const Divider(),
                          Text(
                            'Available Points: $_userAvailablePoints',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          if (!canRedeem)
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                '(Min $minRedeem pts to redeem)',
                                style: const TextStyle(
                                  color: Colors.orange,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _scannedUid = null;
                                _customerName = null;
                                _isScanning = true; // Reset
                                _amountController.clear();
                                _redeemPointsController.clear();
                              });
                            },
                            icon: const Icon(Icons.close),
                            label: const Text("Change Customer"),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Transaction Type
                    Row(
                      children: [
                        Expanded(
                          child: _typeButton(
                            'CREDIT',
                            isActive: _transactionType == 'CREDIT',
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Opacity(
                            opacity: canRedeem ? 1.0 : 0.5,
                            child: IgnorePointer(
                              ignoring: !canRedeem,
                              child: _typeButton(
                                'REDEEM',
                                isActive: _transactionType == 'REDEEM',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Fuel Amount
                    TextField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,2}'),
                        ),
                      ],
                      decoration: InputDecoration(
                        labelText: 'Fuel Amount (₹)',
                        helperText:
                            'Max limit: ₹${((config['maxFuelAmount'] as num?)?.toDouble() ?? 50000.0).toStringAsFixed(0)}',
                        border: const OutlineInputBorder(),
                        prefixText: '₹ ',
                        errorText: _amountError,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Fuel Type
                    if (availableFuels.isEmpty)
                      const Text(
                        'No fuel types available for this bunk.',
                        style: TextStyle(color: Colors.red),
                      )
                    else
                      DropdownButtonFormField<String>(
                        value: validFuelSelection,
                        items: availableFuels
                            .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)),
                            )
                            .toList(),
                        onChanged: (val) =>
                            setState(() => _selectedFuelType = val!),
                        decoration: const InputDecoration(
                          labelText: 'Fuel Type',
                          border: OutlineInputBorder(),
                        ),
                      ),

                    if (_transactionType == 'REDEEM') ...[
                      const SizedBox(height: 16),
                      TextField(
                        controller: _redeemPointsController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Points to Redeem',
                          border: const OutlineInputBorder(),
                          helperText: '1 Point = ₹${config['pointValue'] ?? 1}',
                          errorText: _redeemError,
                        ),
                      ),
                    ],

                    const SizedBox(height: 32),

                    ElevatedButton(
                      onPressed:
                          (_isLoading || !_isValid || availableFuels.isEmpty)
                          ? null
                          : () => _submitTransaction(config, bunk), // Pass Bunk
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: _transactionType == 'CREDIT'
                            ? AppTheme.primaryColor
                            : Colors.orange,
                        disabledBackgroundColor: Colors.grey.shade300,
                        disabledForegroundColor: Colors.grey.shade600,
                        foregroundColor: Colors.white,
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              _transactionType == 'CREDIT'
                                  ? 'CONFIRM PURCHASE'
                                  : 'REDEEM POINTS',
                            ),
                    ),
                  ],
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Error: $err')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) =>
            Center(child: Text('Error loading config: $err')),
      ),
    );
  }

  Widget _typeButton(String type, {required bool isActive}) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _transactionType = type;
          _validate();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isActive
              ? (type == 'CREDIT' ? Colors.blue : Colors.orange)
              : Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
          border: isActive ? null : Border.all(color: Colors.grey),
        ),
        child: Center(
          child: Text(
            type,
            style: TextStyle(
              color: isActive ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submitTransaction(
    Map<String, dynamic> config,
    Map<String, dynamic> bunk,
  ) async {
    final amount = double.tryParse(_amountController.text) ?? 0;

    int pointsToRedeem = 0;
    double discount = 0;
    int pointsEarned = 0;

    if (_transactionType == 'REDEEM') {
      pointsToRedeem = int.tryParse(_redeemPointsController.text) ?? 0;
      final pointValue = (config['pointValue'] as num?)?.toDouble() ?? 1.0;
      discount = pointsToRedeem * pointValue;

      if (discount > amount) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot redeem more than fuel amount')),
        );
        return;
      }
    } else {
      // Manual Calc for Display only (Server does real calc)
      final pct = (config['creditPercentage'] as num?)?.toDouble() ?? 1.0;
      final pVal = (config['pointValue'] as num?)?.toDouble() ?? 1.0;
      pointsEarned = ((amount * (pct / 100)) / pVal).floor();
    }

    final amountPaid = amount - discount;

    setState(() => _isLoading = true);

    try {
      if (bunk['id'] == null) throw Exception("Bunk ID error");

      final requestId = DateTime.now().millisecondsSinceEpoch.toString();

      await FirebaseFunctions.instance
          .httpsCallable('addFuelTransaction')
          .call({
            'userId': _scannedUid,
            'bunkId': bunk['id'],
            'amount': amount,
            'fuelType': _selectedFuelType,
            'isRedeem': _transactionType == 'REDEEM',
            'pointsToRedeem': _transactionType == 'REDEEM' ? pointsToRedeem : 0,
            'requestId': requestId,
          });

      if (mounted) {
        _showSuccessDialog(amountPaid, pointsEarned, pointsToRedeem);
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showError(context, e);
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _showSuccessDialog(
    double amountPaid,
    int pointsEarned,
    int pointsRedeemed,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Success!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Transaction completed successfully.'),
            const SizedBox(height: 16),
            _infoRow("Customer Paid:", "₹${amountPaid.toStringAsFixed(2)}"),
            if (_transactionType == 'CREDIT')
              _infoRow("Points Earned:", "+$pointsEarned")
            else
              _infoRow("Redeemed:", "$pointsRedeemed pts"),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx); // Close Dialog
              Navigator.pop(context); // Close Screen
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }
}

class MaxValueFormatter extends TextInputFormatter {
  final double max;
  MaxValueFormatter(this.max);

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;
    final newDouble = double.tryParse(newValue.text);
    if (newDouble == null) return oldValue;
    if (newDouble > max) return oldValue;
    return newValue;
  }
}
