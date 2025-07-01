import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_database/firebase_database.dart';
import '../api_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io' show Platform;

class LocationService {
  // Singleton pattern
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  // Service properties
  Timer? _locationTimer;
  String? _userId;
  bool _isTracking = false;
  int _errorCount = 0;
  DateTime? _lastUpdateAttempt;
  final ApiService _apiService = ApiService();
  StreamSubscription<Position>? _positionStreamSubscription;
  
  // Add notification plugin
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = 
      FlutterLocalNotificationsPlugin();
  bool _notificationInitialized = false;

  // Get tracking status
  bool get isTracking => _isTracking;

  // Add method to setup background notification
  Future<bool> setupBackgroundNotification({
    required String title,
    required String body,
    required String channelId,
    required String channelName,
    String? icon,
  }) async {
    try {
      // Only needed on Android
      if (!Platform.isAndroid) {
        return true;
      }
      
      // Initialize notifications if not already done
      if (!_notificationInitialized) {
        const AndroidInitializationSettings initializationSettingsAndroid =
            AndroidInitializationSettings('@mipmap/ic_launcher'); // Default app icon
            
        const InitializationSettings initializationSettings = 
            InitializationSettings(android: initializationSettingsAndroid);
            
        await _flutterLocalNotificationsPlugin.initialize(initializationSettings);
        _notificationInitialized = true;
      }
      
      // Create Android notification channel for foreground service
      final AndroidNotificationChannel channel = AndroidNotificationChannel(
        channelId,
        channelName,
        importance: Importance.low, // Low importance to avoid sound/vibration
        showBadge: false,
      );
      
      // Register the channel with the system
      await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
      
      // Create the notification
      const int notificationId = 1; // Use a static ID so we can update the same notification
      AndroidNotificationDetails androidNotificationDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        ongoing: true, // Persistent notification
        autoCancel: false,
        icon: icon ?? '@mipmap/ic_launcher', // Use provided icon or default
        channelShowBadge: false,
      );
      
      NotificationDetails notificationDetails = 
          NotificationDetails(android: androidNotificationDetails);
      
      // Show the notification
      await _flutterLocalNotificationsPlugin.show(
        notificationId,
        title,
        body,
        notificationDetails,
      );
      
      debugPrint('✅ Background notification setup complete');
      return true;
    } catch (e) {
      debugPrint('❌ Error setting up background notification: $e');
      return false;
    }
  }

  // Method for cleaning up resources when the app exits
  Future<void> cleanupForAppExit() async {
    stopLocationTracking();
    
    // Ensure notification is explicitly removed
    try {
      if (Platform.isAndroid && _notificationInitialized) {
        await _flutterLocalNotificationsPlugin.cancel(1);
        debugPrint('✅ Location notification canceled on app exit');
      }
    } catch (e) {
      debugPrint('❌ Error canceling notification on exit: $e');
    }
    
    debugPrint('✅ Location resources cleaned up for app exit');
  }

  // Start location tracking with improved error handling
  Future<bool> startLocationTracking(String userId, {bool enableBackground = false}) async {
    // Always stop previous tracking first to ensure clean state
    stopLocationTracking();
    
    _userId = userId;
    _errorCount = 0;
    _lastUpdateAttempt = null;
    
    try {
      // Check permission first
      bool hasPermission = await _checkLocationPermission();
      if (!hasPermission) {
        debugPrint('❌ Location permission denied for user: $userId');
        return false;
      }
      
      // For background mode, check for background location permission on Android
      if (enableBackground && Platform.isAndroid) {
        LocationPermission backgroundPermission = await Geolocator.checkPermission();
        if (backgroundPermission != LocationPermission.always) {
          debugPrint('⚠️ Background location permission not granted');
          backgroundPermission = await Geolocator.requestPermission();
          if (backgroundPermission != LocationPermission.always) {
            debugPrint('❌ Background location permission denied');
            // We can continue with foreground only as fallback
          }
        }
      }

      // For emulated routes, we need to listen to position CHANGES instead of just polling
      // This will make the app respond to emulator route changes
      _setupPositionStream(enableBackground: enableBackground);

      // Also keep the timer as a backup
      if (enableBackground) {
        // Set a longer timer interval for background updates to save battery
        _locationTimer = Timer.periodic(const Duration(seconds: 60), (_) {
          _updateLocationWithSafety();
        });
        debugPrint('⏰ Set up background timer with 60-second interval');
      } else {
        // Foreground updates can be more frequent
        _locationTimer = Timer.periodic(const Duration(seconds: 10), (_) {
          _updateLocationWithSafety();
        });
        debugPrint('⏰ Set up foreground timer with 3-second interval');
      }

      _isTracking = true;
      
      // Try to update immediately
      _updateLocationWithSafety();
      
      debugPrint('✅ Started location tracking for user: $userId (updating every ${enableBackground ? 60 : 3} seconds)');
      return true;
    } catch (e) {
      debugPrint('❌ Error starting location tracking: $e');
      return false;
    }
  }

  // Stop tracking location
  void stopLocationTracking() {
    _locationTimer?.cancel();
    _locationTimer = null;
    
    // Cancel position stream subscription too
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    
    _isTracking = false;
    _lastUpdateAttempt = null;
    
    // Cancel the persistent notification with improved error handling
    try {
      if (Platform.isAndroid && _notificationInitialized) {
        _flutterLocalNotificationsPlugin.cancel(1);
        debugPrint('✅ Location tracking notification canceled');
      }
    } catch (e) {
      debugPrint('⚠️ Error canceling notification: $e');
    }
    
    if (_userId != null) {
      debugPrint('✅ Stopped location tracking for user: $_userId');
      _userId = null;
    }
  }

  // Initialize service - won't actually do anything for this simpler implementation
  static Future<void> initBackgroundService() async {
    debugPrint('✅ Using simplified location service (no background tasks)');
    return;
  }

  // Safely update location with throttling to prevent overlapping requests
  void _updateLocationWithSafety() {
    // Don't proceed if no userId
    if (_userId == null) return;

    // Check if an update was attempted too recently (within 2 seconds)
    // Reduced from 20 seconds to 2 seconds to match our new interval
    final now = DateTime.now();
    if (_lastUpdateAttempt != null && 
        now.difference(_lastUpdateAttempt!).inSeconds < 2) {
      debugPrint('⚠️ Location update attempted too recently, skipping');
      return;
    }

    // Mark the time of this attempt
    _lastUpdateAttempt = now;
    
    // Use separate try-catch to ensure _lastUpdateAttempt gets reset
    try {
      // Run the location update in a non-blocking way
      unawaited(_getAndUpdateLocation());
    } catch (e) {
      debugPrint('❌ Error initiating location update: $e');
    }
  }

  // Enhanced get and update location with better error handling and fallbacks
  Future<void> _getAndUpdateLocation() async {
    if (_userId == null) return;

    try {
      Position? position;
      bool usingLastKnown = false;
      
      try {
        // First try with standard settings
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.reduced,
          timeLimit: const Duration(seconds: 4),  // Longer timeout for background mode
        );
      } catch (e) {
        debugPrint('⚠️ First attempt failed: $e');
        
        try {
          // Second attempt with lowest accuracy
          position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.lowest,
            timeLimit: const Duration(seconds: 2),
          );
        } catch (e2) {
          debugPrint('⚠️ Second attempt failed: $e2');
          
          try {
            // Last resort: get last known position
            debugPrint('📍 Trying last known position');
            position = await Geolocator.getLastKnownPosition();
            
            if (position != null) {
              usingLastKnown = true;
              debugPrint('📍 Using last known position from ${position.timestamp}');
            } else {
              throw Exception('No last known position available');
            }
          } catch (e3) {
            debugPrint('❌ Failed to get any position: $e3');
            throw e3;
          }
        }
      }

      // If we couldn't get a position, don't proceed
      if (position == null) {
        debugPrint('❌ No position available after all attempts');
        return;
      }

      // Check if position is too old (only for last known position)
      if (usingLastKnown && position.timestamp != null) {
        final now = DateTime.now();
        final positionTime = position.timestamp!;
        final difference = now.difference(positionTime);
        
        // If last known position is more than 3 minutes old, it's not useful
        if (difference.inMinutes > 3) {
          debugPrint('⚠️ Last known position too old (${difference.inMinutes} minutes), skipping update');
          return;
        }
      }

      // Update Firebase first (most important)
      final DatabaseReference dbRef = FirebaseDatabase.instance.ref();
      await dbRef.child('handymen_locations').child(_userId!).update({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'lastUpdated': DateTime.now().toUtc().toIso8601String(),
        'accuracy': position.accuracy,
        'source': usingLastKnown ? 'last_known' : 'current_position',
      });
      
      debugPrint('✅ Updated location in Firebase: ${position.latitude}, ${position.longitude} (${usingLastKnown ? 'last known' : 'current'})');
      
      // Reset error count on success
      _errorCount = 0;
      
      // Also try the API update (non-blocking)
      _apiService.updateHandymanLocation(
        _userId!,
        position.latitude, 
        position.longitude
      ).then((result) {
        if (result['success']) {
          debugPrint('✅ API location update successful');
        } else {
          debugPrint('⚠️ API location update failed: ${result['error']}');
        }
      }).catchError((e) {
        debugPrint('⚠️ Error calling location API: $e');
      });
    } catch (e) {
      _errorCount++;
      debugPrint('❌ Error updating location: $e');
      
      // If we have too many errors, stop tracking but use more tolerance in background mode
      if (_errorCount >= 10) {  // Increased from 5 to 10
        debugPrint('❌ Too many location errors, stopping tracking');
        stopLocationTracking();
      }
    }
  }

  // Check location permission
  Future<bool> _checkLocationPermission() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('❌ Location services are disabled');
        return false;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('❌ Error checking location permission: $e');
      return false;
    }
  }

  // Add a method to set up the position stream:
  void _setupPositionStream({bool enableBackground = false}) {
    // Cancel any existing subscription
    _positionStreamSubscription?.cancel();
    
    // Use location settings optimized for background mode if requested
    LocationSettings locationSettings;
    
    if (enableBackground && Platform.isAndroid) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
        forceLocationManager: false,
        intervalDuration: const Duration(seconds: 30),
        foregroundNotificationConfig: ForegroundNotificationConfig(
          notificationTitle: 'HandyMan Location Service',
          notificationText: 'Your location is being tracked to receive nearby job requests',
          enableWakeLock: true,
          notificationChannelName: 'Location Service',
          // Fix: AndroidResource instead of String
          notificationIcon: const AndroidResource(name: 'ic_launcher', defType: 'mipmap'),
          // Remove the notificationId parameter as it's not supported
        )
      );
      debugPrint('📍 Setting up background location stream with 30-second interval');
    } else {
      locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      );
      debugPrint('📍 Setting up foreground location stream with 5-meter distance filter');
    }
    
    // Start listening to position changes with better error handling
    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings
    ).listen(
      (Position position) {
        // When position changes, update immediately
        debugPrint('📍 Position stream update: ${position.latitude}, ${position.longitude}');
        _updateLocationFromPosition(position);
      },
      onError: (error) {
        debugPrint('❌ Position stream error: $error');
        
        // Automatically try to recover the stream after errors
        Future.delayed(const Duration(seconds: 5), () {
          if (_isTracking && _positionStreamSubscription == null) {
            debugPrint('🔄 Attempting to restart position stream after error');
            _setupPositionStream(enableBackground: enableBackground);
          }
        });
      },
      cancelOnError: false, // Don't cancel subscription on error
    );
    
    debugPrint('✅ Started position stream with background mode: $enableBackground');
  }

  // Add a method to update from position directly:
  Future<void> _updateLocationFromPosition(Position position) async {
    if (_userId == null) return;
    
    try {
      // Update Firebase
      final DatabaseReference dbRef = FirebaseDatabase.instance.ref();
      await dbRef.child('handymen_locations').child(_userId!).update({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'lastUpdated': DateTime.now().toUtc().toIso8601String(),
        'accuracy': position.accuracy,
        'source': 'stream', // Mark that this came from the stream
      });
      
      debugPrint('✅ Stream updated location in Firebase: ${position.latitude}, ${position.longitude}');
      
      // Reset error count and last update time
      _errorCount = 0;
      _lastUpdateAttempt = DateTime.now();
      
      // Also update via API
      _apiService.updateHandymanLocation(
        _userId!,
        position.latitude, 
        position.longitude
      ).then((result) {
        if (result['success']) {
          debugPrint('✅ API location update successful from stream');
        } else {
          debugPrint('⚠️ API location update failed from stream: ${result['error']}');
        }
      }).catchError((e) {
        debugPrint('⚠️ Error calling location API from stream: $e');
      });
    } catch (e) {
      debugPrint('❌ Error updating location from stream: $e');
    }
  }
}

// Helper function to avoid having to use "unawaited" import
void unawaited(Future<void> future) {}