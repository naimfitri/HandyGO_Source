import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async'; // Import Timer class
import 'BookingPage.dart';
import 'api_service.dart'; // Add this import
import 'WalletPage.dart';
import 'ProfilePage.dart';
import 'services/location_service.dart'; // Import the location service
import 'services/database_service.dart'; // Import the database service
import 'services/battery_optimization_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart'; // Import CachedNetworkImage
import 'package:firebase_messaging/firebase_messaging.dart'; // Add this import

// Theme colors
class AppTheme {
  static const Color primaryColor = Color(0xFF3F51B5); // Royal Blue
  static const Color secondaryColor = Color(0xFF9C27B0); // Vibrant Violet
  static const Color backgroundColor = Color(0xFFFAFAFF); // Ghost White
  static const Color textHeadingColor = Color(0xFF2E2E2E); // Dark Slate Gray
  static const Color textBodyColor = Color(0xFF6E6E6E); // Slate Grey
  static const Color successColor = Color(0xFF4CAF50); // Spring Green
  static const Color warningColor = Color(0xFFFF7043); // Coral
  static const Color blueTintBackground = Color(0xFFE3F2FD); // Blue-tint background
  static const Color purpleTintBackground = Color(0xFFF3E5F5); // Purple-tint background
}

class HandymanHomePage extends StatefulWidget {
  final String userId;

  const HandymanHomePage({super.key, required this.userId});

  @override
  State<HandymanHomePage> createState() => _HandymanHomePageState();
}

class _HandymanHomePageState extends State<HandymanHomePage> with SingleTickerProviderStateMixin {
  String? handymanName;
  String? profileImageUrl; // Add this line to store profile image URL
  final ApiService _apiService = ApiService(); // Add API service
  bool _isLoading = true;
  int _currentIndex = 0; // Add this for navigation
  bool _isOnline = false;
  final DatabaseService _databaseService = DatabaseService();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Stats data
  int _totalActiveBookings = 0;
  int _totalCompletedJobs = 0;
  double _remainingPayout = 0.0;
  double _totalRevenue = 0.0;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );

    // Initialize services and fetch data
    _initializeServices();
    _fetchHandymanData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _initializeServices() async {
    try {
      // First check if handyman should be online
      await _checkOnlineStatus();
      
      // Initialize background execution capability
      await _setupBackgroundExecution();

      // Start location services with a delay to avoid app startup issues
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          if (_isOnline) {
            _startLocationTrackingWithBackground().then((success) {
              debugPrint('📍 Location tracking started: $success');
            });
          }
        }
      });
    } catch (e) {
      debugPrint('❌ Error initializing services: $e');
    }
  }
  
  // New method to start location tracking with background capability
  Future<bool> _startLocationTrackingWithBackground() async {
    try {
      // Check if battery optimization is disabled
      await BatteryOptimizationService.requestBatteryOptimizationPermission(context);
      
      // Create persistent notification for background operation
      await LocationService().setupBackgroundNotification(
        title: "HandyGo is active",
        body: "Sharing your location with customers",
        channelId: "location_service_channel",
        channelName: "Location Service",
        icon: "ic_notification" // Make sure this icon exists in Android resources
      );
      
      // Start tracking with background mode enabled
      return await LocationService().startLocationTracking(
        widget.userId,
        enableBackground: true
      );
    } catch (e) {
      debugPrint('❌ Error starting background location: $e');
      return false;
    }
  }
  
  // Setup background execution capability
  Future<void> _setupBackgroundExecution() async {
    try {
      // Request notification permissions for foreground service
      await _checkAndRequestNotificationPermission();
      
      // Register periodic background task if needed
      // This depends on your background fetch implementation
      await _registerBackgroundTasks();
      
      debugPrint('✅ Background execution setup completed');
    } catch (e) {
      debugPrint('❌ Error setting up background execution: $e');
    }
  }
  
  // Register background tasks for periodic updates
  Future<void> _registerBackgroundTasks() async {
    // This is a placeholder for registering background tasks
    // You would implement this using packages like:
    // - workmanager for Android
    // - background_fetch for iOS
    // Example implementation would go here
    
    debugPrint('ℹ️ Background tasks registration should be implemented');
  }

  Future<void> _startLocationTracking() async {
    try {
      // First stop any existing tracking
      LocationService().stopLocationTracking();
      
      // Add delay to ensure proper cleanup
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Then try to start tracking
      final success = await _safeStartLocationTracking();

      if (!success && mounted) {
        // Show dialog to request location permission
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Location Permission Required'),
            content: const Text(
              'This app needs location permission to update your position so customers can find you. Please grant location permission.',
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await LocationService().startLocationTracking(widget.userId);
                },
                child: const Text('Grant Permission', style: TextStyle(color: AppTheme.primaryColor)),
              ),
            ],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            backgroundColor: Colors.white,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error in _startLocationTracking: $e');
    }
  }

  // Add a method to fetch the handyman data
  Future<void> _fetchHandymanData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // First try to get from Firebase Auth
      final user = FirebaseAuth.instance.currentUser;
      String nameFromFirebase = user?.displayName ?? 'Handyman';

      // Then try to get more complete data from your API
      final result = await _apiService.getHandymanData(widget.userId);

      // Also fetch job stats
      await _fetchJobStats();

      // Get profile image separately using the fetchProfileImage API method
      final imageResult = await _apiService.fetchProfileImage(widget.userId);
      String? imageUrl;
      
      if (imageResult['success'] && imageResult['imageUrl'] != null) {
        imageUrl = imageResult['imageUrl'];
        debugPrint('✅ Got profile image URL: $imageUrl');
      }

      setState(() {
        if (result['success'] && result['handymanData'] != null) {
          // Use name from database if available
          handymanName = result['handymanData']['name'] ?? nameFromFirebase;
          // Set profile image URL from handymanData if available and not already set
          if (imageUrl == null && result['handymanData']['profileImage'] != null) {
            profileImageUrl = result['handymanData']['profileImage'];
          } else {
            profileImageUrl = imageUrl;
          }
        } else {
          // Fallback to Firebase displayName
          handymanName = nameFromFirebase;
        }
        _isLoading = false;
      });
    } catch (e) {
      print('⚠️ Error fetching handyman data: $e');

      // Fallback to Firebase Auth
      final user = FirebaseAuth.instance.currentUser;
      setState(() {
        handymanName = user?.displayName ?? 'Handyman';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchJobStats() async {
    try {
      final result = await _apiService.getHandymanJobStats(widget.userId);

      if (result['success']) {
        setState(() {
          _totalActiveBookings = result['activeBookings'] ?? 0;
          _totalCompletedJobs = result['completedJobs'] ?? 0;
          _remainingPayout = result['remainingPayout']?.toDouble() ?? 0.0;
          _totalRevenue = result['totalRevenue']?.toDouble() ?? 0.0;
        });
      }
    } catch (e) {
      print('⚠️ Error fetching job stats: $e');
    }
  }

  // Add this method to build the home content
  Widget _buildHomeContent() {
    return _isLoading
        ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
        : RefreshIndicator(
            onRefresh: () async {
              await _fetchHandymanData();
              await _fetchJobStats();
            },
            color: AppTheme.primaryColor,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome card with avatar
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryColor.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      // Existing row content
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context, 
                            MaterialPageRoute(builder: (context) => ProfilePage(userId: widget.userId))
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: CircleAvatar(
                              radius: 30,
                              backgroundColor: AppTheme.purpleTintBackground,
                              backgroundImage: profileImageUrl != null && profileImageUrl!.isNotEmpty
                                ? CachedNetworkImageProvider(
                                    profileImageUrl!,
                                  )
                                : null,
                              child: profileImageUrl == null || profileImageUrl!.isEmpty
                                ? const Icon(Icons.person_outline, color: AppTheme.primaryColor, size: 40)
                                : null,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Welcome back,',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                handymanName ?? 'Handyman',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Earnings Summary
                  const Text(
                    'Earnings Summary',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textHeadingColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildEarningsItem('Total Revenue', 'RM ${_totalRevenue.toStringAsFixed(2)}', Icons.payments_outlined),
                            Container(width: 1, height: 40, color: Colors.grey.withOpacity(0.2)),
                            _buildEarningsItem('Pending Payout', 'RM ${_remainingPayout.toStringAsFixed(2)}', Icons.account_balance_wallet_outlined),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Job Statistics
                  const Text(
                    'Job Statistics',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textHeadingColor,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Job Stats Cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Total Active\nBookings', 
                          _totalActiveBookings.toString(), 
                          Icons.calendar_today_outlined,  // Changed to outlined icon
                          AppTheme.primaryColor,  // Using theme color
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatCard(
                          'Total Completed\nJobs', // Main label
                          _totalCompletedJobs.toString(), // Value
                          Icons.check_circle_outline,
                          AppTheme.successColor,  // Using theme success color
                          'Paid & Unpaid', // Add this optional subtitle
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Quick Actions
                  const Text(
                    'Quick Actions',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textHeadingColor,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Action Cards
                  GridView.count(
                    shrinkWrap: true,
                    crossAxisCount: 3,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.9,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildActionCard(context, Icons.work_outline, 'My Jobs', 1, AppTheme.primaryColor),
                      _buildActionCard(context, Icons.person_outline, 'Profile', 3, AppTheme.secondaryColor),
                      _buildActionCard(context, Icons.account_balance_wallet_outlined, 'Wallet', 2, AppTheme.successColor),
                    ],
                  ),
                ],
              ),
            ),
          );
  }

  // Function to toggle online status
  void _toggleOnlineStatus() async {
    // Show loading indicator
    setState(() {
      _isLoading = true;
    });
    
    bool newStatus = !_isOnline;
    bool success = false;
    
    try {
      if (newStatus) {
        // Coming online - first ensure location service is stopped before starting again
        LocationService().stopLocationTracking();
        
        // Add a small delay to ensure the service is properly stopped
        await Future.delayed(const Duration(milliseconds: 500));
        
        // Now start location tracking with proper error handling
        success = await _safeStartLocationTracking();
      } else {
        // Going offline - stop location tracking
        LocationService().stopLocationTracking();
        success = true;
      }
      
      // Update database
      if (success) {
        await _databaseService.updateHandymanStatus(widget.userId, newStatus);
        await _updateOnlineStatusInStorage(newStatus);
        
        setState(() {
          _isOnline = newStatus;
        });
        
        if (_isOnline) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You are now online! Customers can find you.'),
              backgroundColor: AppTheme.successColor,  // Using theme success color
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('You are now offline. Your location is no longer shared.'),
              backgroundColor: Colors.grey.shade600,  // Darker grey
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to update status. Please check your location settings.'),
            backgroundColor: AppTheme.warningColor,  // Using theme warning color
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error toggling online status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppTheme.warningColor,  // Using theme warning color
          duration: const Duration(seconds: 2),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Added safe start location tracking method with additional error handling
  Future<bool> _safeStartLocationTracking() async {
    try {
      // Check notification permissions first
      await _checkAndRequestNotificationPermission();
      
      // Try to start tracking with multiple safety measures
      return await LocationService().startLocationTracking(widget.userId);
    } catch (e) {
      debugPrint('❌ Error in _safeStartLocationTracking: $e');
      
      // Show permission dialog if needed
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Location Permission Required'),
            content: const Text(
              'This app needs location permission to update your position so customers can find you. Please grant location permission.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  try {
                    // Try again after user acknowledges
                    await LocationService().startLocationTracking(widget.userId);
                  } catch (err) {
                    debugPrint('❌ Error after permission dialog: $err');
                  }
                },
                child: const Text('Grant Permission', style: TextStyle(color: AppTheme.primaryColor)),
              ),
            ],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            backgroundColor: Colors.white,
          ),
        );
      }
      
      return false;
    }
  }
  
  // New method to check and request notification permissions
  Future<void> _checkAndRequestNotificationPermission() async {
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.getNotificationSettings();
      
      if (settings.authorizationStatus != AuthorizationStatus.authorized) {
        debugPrint('📱 Requesting notification permissions');
        
        // Request notification permission
        final newSettings = await messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: false,
        );
        
        debugPrint('📱 Notification authorization status: ${newSettings.authorizationStatus}');
        
        // If user denied permission, show dialog explaining why it's needed
        if (newSettings.authorizationStatus == AuthorizationStatus.denied && mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Notification Permission'),
              content: const Text(
                'Notifications help you stay updated on new job requests and important updates. '
                'You can enable them in your device settings.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK', style: TextStyle(color: AppTheme.primaryColor)),
                ),
              ],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              backgroundColor: Colors.white,
            ),
          );
        }
      } else {
        debugPrint('📱 Notification permissions already granted');
      }
    } catch (e) {
      debugPrint('❌ Error checking notification permissions: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,  // Using theme background color
      // Only show AppBar for home tab
      appBar: _currentIndex == 0
          ? AppBar(
              centerTitle: true,
              title: const Text(
                'HandyGo',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 24, // You can adjust size as needed
                ),
              ),
              backgroundColor: AppTheme.primaryColor,  // Using theme primary color
              elevation: 0,
              // actions: [
              //   IconButton(
              //     icon: const Icon(Icons.notifications_outlined, color: Colors.white),
              //     onPressed: () {
              //       // Notifications functionality
              //     },
              //   ),
              //   IconButton(
              //     icon: const Icon(Icons.logout_outlined, color: Colors.white),  // Changed to outlined icon
              //     onPressed: () async {
              //       await FirebaseAuth.instance.signOut();
              //       Navigator.pushReplacementNamed(context, '/login');
              //     },
              //   ),
              // ],
              shape: const RoundedRectangleBorder(  // Adding rounded corners to app bar
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(16),
                ),
              ),
            )
          : null,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildHomeContent(), // Home Tab with dashboard content
          BookingPage(userId: widget.userId), // Bookings Tab
          WalletPage(userId: widget.userId), // Wallet Tab
          ProfilePage(userId: widget.userId), // Profile Tab
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      floatingActionButton: _buildPowerButton(),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppTheme.primaryColor,  // Using theme primary color
        unselectedItemColor: const Color(0xFF9E9E9E),  // Using specified unselected color
        backgroundColor: Colors.white,  // Using white background as specified
        showUnselectedLabels: true,
        currentIndex: _currentIndex,
        elevation: 8,  // Adding elevation for shadow
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), label: "Dashboard"),  // Changed to outlined icon
          BottomNavigationBarItem(icon: Icon(Icons.calendar_month_outlined), label: "Bookings"),  // Changed to outlined icon
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_outlined), label: "Wallet"),  // Changed to outlined icon
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: "Profile"),  // Changed to outlined icon
        ],
      ),
    );
  }

  // Update your action card to use tab indices
  Widget _buildActionCard(BuildContext context, IconData icon, String label, int tabIndex, Color color) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = tabIndex;
        });
      },
      child: Container(
        // Existing styling
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppTheme.textHeadingColor,  // Using theme heading text color
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEarningsItem(String title, String value, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: AppTheme.textBodyColor),  // Using theme body text color
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  color: AppTheme.textBodyColor,  // Using theme body text color
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textHeadingColor,  // Using theme heading text color
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color, [String? subtitle]) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              // Using proper background tint based on the icon color
              color: color == AppTheme.primaryColor 
                ? AppTheme.blueTintBackground  // Blue tint for primary
                : (color == AppTheme.secondaryColor 
                  ? AppTheme.purpleTintBackground  // Purple tint for secondary
                  : color.withOpacity(0.1)),  // Default opacity for others
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppTheme.textHeadingColor,  // Using theme heading text color
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.textBodyColor,  // Using theme body text color
              fontSize: 13,
              height: 1.4,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                subtitle,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPowerButton() {
    return FloatingActionButton(
      heroTag: 'powerButton',
      onPressed: _isLoading ? null : _toggleOnlineStatus,
      backgroundColor: _isLoading 
          ? Colors.grey
          : (_isOnline ? AppTheme.successColor : Colors.grey),
      elevation: 4,
      shape: const CircleBorder(),  // Using theme success color for online state
      child: Stack(
        alignment: Alignment.center,
        children: [
          _isLoading 
              ? const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 2.0,
                )
              : const Icon(
                  Icons.power_settings_new_outlined,  // Changed to outlined power icon
                  color: Colors.white,
                  size: 30,
                ),
          if (_isOnline && !_isLoading)
            Positioned(
              top: 13,
              right: 13, 
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.6),
                      blurRadius: 6,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Check if handyman was previously online
  Future<void> _checkOnlineStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      bool wasOnline = prefs.getBool('handyman_is_online_${widget.userId}') ?? false;
      
      setState(() {
        _isOnline = wasOnline;
      });
      
      debugPrint('📍 Handyman previous online status: $_isOnline');
    } catch (e) {
      debugPrint('❌ Error checking online status: $e');
      setState(() {
        _isOnline = false;
      });
    }
  }

  // Save online status to persistent storage
  Future<void> _updateOnlineStatusInStorage(bool isOnline) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('handyman_is_online_${widget.userId}', isOnline);
      debugPrint('✅ Saved online status: $isOnline');
    } catch (e) {
      debugPrint('❌ Error saving online status: $e');
    }
  }
}
