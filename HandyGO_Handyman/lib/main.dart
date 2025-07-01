import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'services/fcm_service.dart';
// Screens
import 'login.dart';
import 'handyman_register.dart';
import 'HandymanHomePage.dart';
import 'ProfilePage.dart';
import 'WalletPage.dart';
import 'BookingPage.dart' as booking;
import 'services/location_service.dart';
import 'welcome_page.dart'; // Import the new welcome page


// Handle background messages
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Don't initialize Firebase here - it should already be initialized
  print("Handling a background message: ${message.messageId}");
}

// Initialize the notification channel for Android
const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'high_importance_channel',
  'High Importance Notifications',
  description: 'This channel is used for important notifications.',
  importance: Importance.high,
);

// Initialize FlutterLocalNotificationsPlugin
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// Add error handling zone
void main() async {
  // Ensure Flutter binding is initialized first
  WidgetsFlutterBinding.ensureInitialized();

  // Catch Flutter errors
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('🔴 Flutter error: ${details.exception}');
  };

  // Catch all other errors using a zone
  runZonedGuarded(() async {
    try {
      // Initialize Firebase with a timeout
      await Firebase.initializeApp().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint('⚠️ Firebase initialization timed out, continuing anyway');
          // Throwing an exception to be caught by the surrounding try-catch block
          throw TimeoutException('Firebase initialization timed out');
        },
      );

      debugPrint('✅ Firebase initialized successfully');

      // Set up FCM background message handler AFTER Firebase initialization
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Important: Initialize FCM early, not just after login
      // This doesn't require a user to be logged in - it just sets up the infrastructure
      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // Create Android notification channel
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
      
      // Initialize FCM even before login - it will handle permissions
      // This doesn't register tokens yet, just prepares the notification system
      await FCMService.initializeNotifications();

      // Initialize background services with a timeout
      try {
        await LocationService.initBackgroundService().timeout(
          const Duration(seconds: 3),
          onTimeout: () {
            debugPrint('⚠️ Background service initialization timed out');
            return;
          },
        );
      } catch (e) {
        debugPrint('⚠️ Background service initialization error: $e');
        // Continue anyway, this is not critical
      }

      // Add a handler for when the app is being terminated
      if (Platform.isAndroid) {
        // Add system channel for detecting app exit
        const platform = MethodChannel('app.channel/cleanup');
        platform.setMethodCallHandler((call) async {
          if (call.method == 'appExit') {
            debugPrint('📱 App is exiting, cleaning up resources...');
            await LocationService().cleanupForAppExit();
          }
          return null;
        });
      }

      // Register a callback to be notified when the app is about to terminate
      WidgetsBinding.instance.addObserver(AppLifecycleObserver());
      
      runApp(const MyApp());
    } catch (e, stack) {
      debugPrint('🔴 Error during app initialization: $e');
      debugPrint('Stack trace: $stack');

      // Run a minimal app that shows the error
      runApp(MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 80),
                  const SizedBox(height: 16),
                  const Text(
                    'Initialization Error',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error: $e',
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      main();
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ));
    }
  }, (error, stack) {
    debugPrint('🔴 Uncaught error: $error');
    debugPrint('Stack trace: $stack');
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Handyman App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF3F51B5),
        scaffoldBackgroundColor: const Color(0xFFFAFAFF),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF3F51B5),
          elevation: 0,
        ),
        fontFamily: 'Poppins', // Or your preferred font
      ),
      home: const ConfirmQuitWrapper(child: WelcomePage()), // Wrap with ConfirmQuitWrapper
      routes: {
        '/login': (context) => const LoginPage(),
        '/register': (context) => const HandymanRegisterPage(),
        '/wallet': (context) {
          final user = FirebaseAuth.instance.currentUser;
          return WalletPage(userId: user?.uid ?? 'unknownUserId');
        },
        '/home': (context) {
          // First check if userId was passed as an argument
          final userId = ModalRoute.of(context)?.settings.arguments as String?;
          // If userId exists in arguments, use it; otherwise fall back to FirebaseAuth
          if (userId != null) {
            return HandymanHomePage(userId: userId);
          } else {
            final user = FirebaseAuth.instance.currentUser;
            return HandymanHomePage(userId: user?.uid ?? 'unknownUserId');
          }
        },
        '/bookings': (context) {
          final user = FirebaseAuth.instance.currentUser;
          return booking.BookingPage(userId: user?.uid ?? 'unknownUserId');
        },
        '/profile': (context) {
          final user = FirebaseAuth.instance.currentUser;
          return ProfilePage(userId: user?.uid ?? 'unknownUserId');
        },
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          // Initialize FCM when user logs in
          FCMService.initializeNotifications();
          
          // Remove automatic location tracking start
          // Location tracking should only start when user goes online
          // LocationService().startLocationTracking(snapshot.data!.uid);
          
          // Return HandymanHomePage directly
          return HandymanHomePage(userId: snapshot.data!.uid);
        } else {
          // Clear FCM token when user logs out
          FCMService.clearNotifications();
          
          // Stop location tracking when user logs out
          LocationService().stopLocationTracking();
          return const LoginPage();
        }
      },
    );
  }
}

// Add this class to your main.dart file
class AppLifecycleObserver extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      // This is called when the app is about to be terminated
      LocationService().cleanupForAppExit();
    }
  }
}

class ConfirmQuitWrapper extends StatelessWidget {
  final Widget child;
  
  const ConfirmQuitWrapper({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Only show the dialog if we're at the root route
        if (Navigator.of(context).canPop()) {
          return true; // Allow normal back navigation
        }
        
        // Show the confirm quit dialog
        final result = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Confirm Exit'),
            content: const Text('Are you sure you want to exit the app?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Exit', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
        
        // Return true to exit the app, or false to stay
        return result ?? false;
      },
      child: child,
    );
  }
}
