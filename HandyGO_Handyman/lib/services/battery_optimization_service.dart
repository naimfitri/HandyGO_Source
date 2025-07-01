import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class BatteryOptimizationService {
  // Add a flag to prevent multiple dialogs
  static bool _dialogShown = false;

  static Future<void> requestBatteryOptimizationPermission(BuildContext context) async {
    // Prevent multiple dialogs
    if (_dialogShown) return;
    
    try {
      final status = await Permission.ignoreBatteryOptimizations.status;
      
      if (!status.isGranted && context.mounted && !_dialogShown) {
        _dialogShown = true;
        
        // Use a safer way to show dialog that won't fail if context is invalid
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Battery Optimization'),
            content: const Text(
              'To ensure reliable location updates, please disable battery optimization for this app.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  _dialogShown = false;
                },
                child: const Text('Later'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.of(dialogContext).pop();
                  try {
                    await Permission.ignoreBatteryOptimizations.request();
                  } catch (e) {
                    debugPrint('⚠️ Error requesting battery optimization permission: $e');
                  }
                  _dialogShown = false;
                },
                child: const Text('Disable Optimization'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      _dialogShown = false;
      debugPrint('⚠️ Error in battery optimization service: $e');
    }
  }

  // Add a method to check if battery optimization is disabled
  static Future<bool> isBatteryOptimizationDisabled() async {
    try {
      final status = await Permission.ignoreBatteryOptimizations.status;
      return status.isGranted;
    } catch (e) {
      debugPrint('⚠️ Error checking battery optimization status: $e');
      return false;
    }
  }
}