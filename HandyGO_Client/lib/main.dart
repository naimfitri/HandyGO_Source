import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'services/stripe_service.dart';
import 'services/fcm_service.dart';
import 'login.dart';
import 'get_start.dart'; // ✅ Import GetStartedPage
import 'wallet/WalletPage.dart';
import 'ProfilePage.dart';
import 'HomePage.dart';
import 'package:firebase_database/firebase_database.dart';
import 'JobDetailsPage.dart'; // ✅ Import JobDetailsPage
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'api_service.dart'; // Add import for ApiService

// Handle background messages
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); 
  
  // Initialize FCM (just permissions and listeners)
  await FCMService.initializeNotifications();
  
  // Set up FCM background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  
  // Create Android notification channel
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
      
  // Update FCM settings
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );
  
  // Try to initialize Stripe but continue even if it fails
  try {
    await StripeService.initialize();
  } catch (e) {
    debugPrint('Stripe initialization failed: $e');
    // Continue without Stripe if it fails to initialize
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const InitialScreen(),
      routes: {
        '/login': (context) => LoginPage(),
        '/home': (context) {
          // Get the arguments if any
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          final userId = args?['userId'] ?? '';
          final user = FirebaseAuth.instance.currentUser;
          return HomePage(
            userId: userId,
            userName: user?.displayName ?? 'Unknown User',
            userEmail: user?.email ?? 'unknown@example.com',
          );
        },
        '/wallet': (context) {
          final user = FirebaseAuth.instance.currentUser;
          return WalletPage(
            userId: user?.uid ?? 'unknownUserId',
            userName: user?.displayName ?? 'Unknown User',
            initialWalletBalance: 100.0,
          );
        },
        '/profile': (context) {
          final user = FirebaseAuth.instance.currentUser;
          return ProfilePage(
            userId: user?.uid ?? 'unknownUserId',
          );
        },
        '/job-details': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return JobDetailsPage(jobId: args['jobId']);
        },
      },
    );
  }
}

// ✅ Handles Firebase Initialization and Redirection
class InitialScreen extends StatefulWidget {
  const InitialScreen({Key? key}) : super(key: key);

  @override
  _InitialScreenState createState() => _InitialScreenState();
}

class _InitialScreenState extends State<InitialScreen> {
  final ApiService _apiService = ApiService(); // Create ApiService instance
  
  @override
  void initState() {
    super.initState();
    
    // Set up notification handlers (but not token registration)
    _setupNotifications();
  }
  
  Future<void> _setupNotifications() async {
    try {
      // Initialize local notifications
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
          
      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: null,
      );
      
      await flutterLocalNotificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          // Handle notification tap
          final payload = response.payload;
          if (payload != null) {
            debugPrint('Notification tapped with payload: $payload');
            // Navigate to job details if needed
            Navigator.pushNamed(context, '/job-details', arguments: {'jobId': payload});
          }
        },
      );

      // Handle incoming messages when app is in foreground
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Got a message while in the foreground!');
        debugPrint('Message data: ${message.data}');
        
        if (message.notification != null) {
          debugPrint('Message also contained a notification: ${message.notification!.title}');
          
          // Display the notification using local notifications plugin
          flutterLocalNotificationsPlugin.show(
            message.hashCode,
            message.notification!.title,
            message.notification!.body,
            NotificationDetails(
              android: AndroidNotificationDetails(
                channel.id,
                channel.name,
                channelDescription: channel.description,
                icon: '@mipmap/ic_launcher',
                priority: Priority.high,
              ),
            ),
            payload: message.data['jobId'],
          );
        }
      });

      // Handle notification clicks when app is in background/terminated
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('A notification was clicked when app was in background!');
        debugPrint('Message data: ${message.data}');
        
        if (message.data.containsKey('jobId')) {
          final jobId = message.data['jobId'];
          // Navigate to job details page
          Navigator.pushNamed(context, '/job-details', arguments: {'jobId': jobId});
        }
      });
    } catch (e) {
      debugPrint('Error setting up notifications: $e');
    }
  }

  Future<void> _uploadTokenViaApi(String userId, String token) async {
    try {
      final response = await _apiService.registerNotificationToken(
        userId,
        token,
        'users' // Change to 'handymen' if this is the handyman app
      );
      
      if (response.statusCode == 200) {
        print('Token uploaded via API successfully');
      } else {
        print('Failed to upload token via API: ${response.body}');
      }
    } catch (e) {
      print('Error uploading token via API: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: FirebaseAuth.instance.authStateChanges().first, // ✅ Check auth status
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          return WalletPage(
            userId: user.uid,
            userName: user.displayName ?? 'Unknown User',
            initialWalletBalance: 100.0,
          );
        } else {
          return GetStartedPage(); // ✅ Show GetStartedPage first
        }
      },
    );
  }
}
