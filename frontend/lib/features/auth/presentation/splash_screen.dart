import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.local_gas_station,
              size: 80,
              color: AppTheme.primaryColor,
            ),
            SizedBox(height: 20),
            CircularProgressIndicator(color: AppTheme.secondaryColor),
          ],
        ),
      ),
    );
  }
}
