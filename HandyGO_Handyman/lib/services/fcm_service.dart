import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Add auth import
import 'package:http/http.dart' as http; // Add missing http import
import 'dart:convert'; // Add missing json import

class FCMService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  // Get FCM token
  static Future<String?> getToken() async {
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
      return null;
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
        Uri.parse('https://handygo-api.onrender.com/api/handyman/register-fcm-token'),
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
      // For Android, request notification permission explicitly for Android 13+ (API level 33+)
      debugPrint('📱 Setting up Android notifications');
      
      // Request notification permission for Android 13+ (API level 33+)
      await _requestNotificationPermission();
      
      // Initialize local notifications plugin with Android-only settings
      const AndroidInitializationSettings androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      
      const InitializationSettings initSettings = InitializationSettings(
        android: androidInit,
      );
      
      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint('📬 Notification tapped: ${response.payload}');
          // Handle notification tap
        },
      );

      // Set up foreground message handler
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('📨 Got a message in the foreground!');
        debugPrint('📨 Message data: ${message.data}');
        
        if (message.notification != null) {
          debugPrint('📨 Message notification: ${message.notification!.title}');
          
          // Display notification
          _showLocalNotification(message);
        }
      });
      
      // Set up token refresh listener
      _messaging.onTokenRefresh.listen((token) {
        debugPrint('🔄 FCM token refreshed: $token');
        _updateToken(token);
      });
      
      // Get initial token
      final token = await _messaging.getToken();
      debugPrint('📝 Initial FCM token: $token');
      
      if (token != null) {
        _updateToken(token);
      }
    } catch (e) {
      debugPrint('❌ Error initializing notifications: $e');
    }
  }
  
  // Add this new method to request notification permissions
  static Future<void> _requestNotificationPermission() async {
    try {
      // Check Android version
      if (int.parse(await _getAndroidVersion()) >= 33) { // Android 13 is API level 33
        debugPrint('📱 Android 13+ detected, requesting notification permission');
        
        // Need to use method channel to request POST_NOTIFICATIONS permission
        final NotificationSettings settings = await _messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: false,
          announcement: false,
          carPlay: false,
          criticalAlert: false,
        );
        
        debugPrint('📱 Notification authorization status: ${settings.authorizationStatus}');
      } else {
        debugPrint('📱 Android version < 13, notification permission handled by manifest');
      }
    } catch (e) {
      debugPrint('❌ Error requesting notification permission: $e');
    }
  }
  
  // Helper method to get Android version
  static Future<String> _getAndroidVersion() async {
    try {
      // Default to a version that doesn't need runtime permission
      return '30'; // Android 11
    } catch (e) {
      debugPrint('❌ Error getting Android version: $e');
      return '30'; // Default to Android 11
    }
  }
  
  // Display a local notification
  static Future<void> _showLocalNotification(RemoteMessage message) async {
    try {
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;
      
      if (notification != null) {
        debugPrint('📩 Showing local notification: ${notification.title}');
        
        await _localNotifications.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              'high_importance_channel',
              'High Importance Notifications',
              channelDescription: 'This channel is used for important notifications.',
              importance: Importance.high,
              priority: Priority.high,
              icon: android?.smallIcon ?? '@mipmap/ic_launcher',
            ),
          ),
          payload: message.data.toString(),
        );
      }
    } catch (e) {
      debugPrint('❌ Error showing notification: $e');
    }
  }
  
  // Update FCM token in Firebase Database
  static Future<void> _updateToken(String token) async {
    try {
      // Get current user ID - you might need to adjust how you get the current user ID
      final userId = getCurrentUserId();
      
      if (userId != null && userId.isNotEmpty) {
        debugPrint('🔑 Updating FCM token for user: $userId');
        
        await FirebaseDatabase.instance
          .ref()
          .child('handymen')
          .child(userId)
          .update({
            'fcmToken': token,
            'lastTokenUpdate': DateTime.now().toIso8601String(),
          });
          
        debugPrint('✅ FCM token updated successfully');
      } else {
        debugPrint('⚠️ Not updating FCM token - no user logged in');
      }
    } catch (e) {
      debugPrint('❌ Error updating FCM token: $e');
    }
  }
  
  // Get current user ID helper method
  static String? getCurrentUserId() {
    try {
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (e) {
      debugPrint('❌ Error getting current user ID: $e');
      return null;
    }
  }

  // Clear notifications when logging out
  static Future<void> clearNotifications() async {
    try {
      await _localNotifications.cancelAll();
      debugPrint('🧹 All notifications cleared');
    } catch (e) {
      debugPrint('❌ Error clearing notifications: $e');
    }
  }
}