import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';

class FCMService {
  // Get FCM token
  static Future<String?> getToken() async {
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
      return null;
    }
  }
  
  // Save FCM token to database for a user
  static Future<bool> saveTokenForUser(String userId) async {
    try {
      final token = await getToken();
      
      if (token == null) {
        debugPrint('No token available to save');
        return false;
      }
      
      // Try direct database update
      try {
        await FirebaseDatabase.instance.ref()
          .child('users')
          .child(userId)
          .update({
            'fcmToken': token,
            'tokenUpdatedAt': DateTime.now().toIso8601String(),
          });
        debugPrint('Saved FCM token directly to database for user: $userId');
        return true;
      } catch (e) {
        debugPrint('Error saving token directly to Firebase: $e');
        // If direct update fails, try API
        return await _uploadTokenViaApi(userId, token);
      }
    } catch (e) {
      debugPrint('Error in saveTokenForUser: $e');
      return false;
    }
  }
  
  // Save FCM token for a handyman
  static Future<bool> saveTokenForHandyman(String handymanId) async {
    try {
      final token = await getToken();
      
      if (token == null) {
        debugPrint('No token available to save');
        return false;
      }
      
      // Try direct database update
      try {
        await FirebaseDatabase.instance.ref()
          .child('handymen')
          .child(handymanId)
          .update({
            'fcmToken': token,
            'tokenUpdatedAt': DateTime.now().toIso8601String(),
          });
        debugPrint('Saved FCM token directly to database for handyman: $handymanId');
        return true;
      } catch (e) {
        debugPrint('Error saving token directly to Firebase: $e');
        // If direct update fails, try API
        return await _uploadTokenViaApi(handymanId, token, userType: 'handymen');
      }
    } catch (e) {
      debugPrint('Error in saveTokenForHandyman: $e');
      return false;
    }
  }
  
  // Upload token via API
  static Future<bool> _uploadTokenViaApi(String userId, String token, {String userType = 'users'}) async {
    try {
      final response = await http.post(
        Uri.parse('https://handygo-api.onrender.com/api/register-fcm-token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'token': token,
          'userType': userType
        }),
      );
      
      if (response.statusCode == 200) {
        debugPrint('Token uploaded via API successfully');
        return true;
      } else {
        debugPrint('Failed to upload token via API: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('Error uploading token via API: $e');
      return false;
    }
  }
  
  // Initialize notifications (call this in main.dart)
  static Future<void> initializeNotifications() async {
    try {
      // Request permission
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      
      debugPrint('User granted notification permission: ${settings.authorizationStatus}');
      
      // Set up token refresh handler
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        debugPrint('FCM token refreshed. Will update on next login.');
      });
      
    } catch (e) {
      debugPrint('Error initializing notifications: $e');
    }
  }
}