import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:http/http.dart' as http;

class StripeService {
  static const String _apiBase = 'https://handygo-api.onrender.com'; // Your backend URL
  static bool _isInitialized = false;

  // Initialize Stripe - call this in main.dart
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Use different keys based on platform
      if (Platform.isAndroid) {
        Stripe.publishableKey = 'pk_test_51REgcgEOsGyLhQ3PmV7ZcFXyEF1zKI8BcZVkipJOCbpyxUGahCWnhn16ENYlfd6ETNK9NaSDSykjLaczzeYBu1Dt002P0IierT';
      } else if (Platform.isIOS) {
        Stripe.publishableKey = 'pk_test_51REgcgEOsGyLhQ3PmV7ZcFXyEF1zKI8BcZVkipJOCbpyxUGahCWnhn16ENYlfd6ETNK9NaSDSykjLaczzeYBu1Dt002P0IierT';
        // iOS may require additional configuration
        Stripe.merchantIdentifier = 'merchant.com.handygo';
      }
      
      await Stripe.instance.applySettings();
      _isInitialized = true;
      debugPrint('✅ Stripe successfully initialized');
    } catch (e) {
      debugPrint('❌ Failed to initialize Stripe: $e');
      // Don't mark as initialized if there's an error so we can retry
      _isInitialized = false;
      rethrow;
    }
  }

  // Create payment intent on the server
  static Future<Map<String, dynamic>> processPayment({
    required double amount,
    required String userId,
    required String userName,
  }) async {
    // Always try to initialize before processing payment
    if (!_isInitialized) {
      try {
        await initialize();
      } catch (e) {
        debugPrint('Cannot process payment - Stripe initialization failed: $e');
        return {
          'success': false,
          'error': 'Stripe initialization failed: $e',
        };
      }
    }

    try {
      // Convert amount to smallest currency unit (cents)
      final int amountInCents = (amount * 100).toInt();
      
      // 1. Create payment intent on the backend
      final response = await http.post(
        Uri.parse('$_apiBase/api/user/create-payment-intent'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'amount': amountInCents,
          'currency': 'myr',
          'userId': userId,
          'userName': userName,
        }),
      );

      if (response.statusCode != 200) {
        throw 'Failed to create payment intent: ${response.statusCode}';
      }
      
      final paymentIntentData = json.decode(response.body);
      final clientSecret = paymentIntentData['clientSecret'];
      
      // 2. Configure payment sheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          merchantDisplayName: 'HandyGo',
          paymentIntentClientSecret: clientSecret,
          appearance: const PaymentSheetAppearance(
            colors: PaymentSheetAppearanceColors(
              primary: Colors.blue,
            ),
            shapes: PaymentSheetShape(
              borderRadius: 12.0,
              borderWidth: 1.0,
            ),
          ),
        ),
      );

      // 3. Present the payment sheet
      await Stripe.instance.presentPaymentSheet();
      
      // 4. Payment success - record the transaction
      final confirmResponse = await http.post(
        Uri.parse('$_apiBase/api/user/confirm-payment'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'paymentIntentId': paymentIntentData['paymentIntentId'],
          'userId': userId,
          'amount': amount,
          'userName': userName,
        }),
      );
      
      if (confirmResponse.statusCode == 200) {
        return {
          'success': true,
          'amount': amount,
        };
      } else {
        return {
          'success': true,
          'error': 'Failed to record payment in database',
          'amount': amount,
        };
      }
    } on StripeException catch (e) {
      return {
        'success': false,
        'error': '${e.error.localizedMessage}',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Error processing payment: $e',
      };
    }
  }
}