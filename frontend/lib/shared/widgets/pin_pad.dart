import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class PinPad extends StatelessWidget {
  final Function(String) onDigit;
  final Function() onDelete;
  final Function() onSubmit; // Or auto submit on 4 digits
  final bool biometricEnabled; // For future
  final bool canSubmit;

  const PinPad({
    super.key,
    required this.onDigit,
    required this.onDelete,
    required this.onSubmit,
    this.biometricEnabled = false,
    this.canSubmit = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (var j = 1; j <= 3; j++)
                  _buildDigit(context, (i * 3 + j).toString()),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildControl(
                context,
                icon: biometricEnabled ? Icons.fingerprint : Icons.check,
                onTap: biometricEnabled ? null : (canSubmit ? onSubmit : null),
                show: true, // Always show something (Biometric or Done)
                isActive: !biometricEnabled && canSubmit,
              ),
              _buildDigit(context, "0"),
              _buildControl(
                context,
                icon: Icons.backspace_outlined,
                onTap: onDelete,
                show: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDigit(BuildContext context, String digit) {
    return InkWell(
      onTap: () => onDigit(digit),
      customBorder: const CircleBorder(),
      child: Container(
        width: 72,
        height: 72,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.surfaceColor,
          border: Border.all(color: Colors.white10),
        ),
        child: Text(
          digit,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildControl(
    BuildContext context, {
    IconData? icon,
    VoidCallback? onTap,
    required bool show,
    bool isActive = false,
  }) {
    if (!show) return const SizedBox(width: 72, height: 72);
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 72,
        height: 72,
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 28,
          color: isActive ? AppTheme.primaryColor : Colors.grey,
        ),
      ),
    );
  }
}
