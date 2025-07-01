import 'package:flutter/material.dart';
import 'api_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_database/firebase_database.dart';
import 'services/fcm_service.dart';

// Add app theme class
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

class HandymanRestrictedProfilePage extends StatefulWidget {
  final String userId;
  final Map<String, dynamic> handymanData;
  
  const HandymanRestrictedProfilePage({
    Key? key,
    required this.userId,
    required this.handymanData,
  }) : super(key: key);

  @override
  State<HandymanRestrictedProfilePage> createState() => _HandymanRestrictedProfilePageState();
}

class _HandymanRestrictedProfilePageState extends State<HandymanRestrictedProfilePage> {
  late Map<String, dynamic> _handymanData;
  bool _isRefreshing = false;
  final ApiService _apiService = ApiService();
  
  @override
  void initState() {
    super.initState();
    _handymanData = widget.handymanData;
  }
  
  // Method to refresh handyman data from server
  Future<void> _refreshHandymanData() async {
    setState(() {
      _isRefreshing = true;
    });

    try {
      // Call API service to get latest handyman data
      final result = await _apiService.getHandymanData(widget.userId);

      if (result['success']) {
        setState(() {
          _handymanData = result['handymanData'];
        });

        // Check if status changed to active
        if (_handymanData['status'] == 'active') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🎉 Your account has been approved! Redirecting to dashboard...'),
              backgroundColor: Colors.green,
            ),
          );

          // Register FCM token before navigating
          await _registerFCMToken(widget.userId);

          // Navigate to main home page after short delay
          Future.delayed(const Duration(seconds: 2), () {
            Navigator.pushReplacementNamed(
              context, 
              '/home',
              arguments: widget.userId,
            );
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Your account is still pending approval'),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ ${result['error']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Failed to refresh: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isRefreshing = false;
      });
    }
  }

  // Add this method inside your _HandymanRestrictedProfilePageState class
  Future<void> _registerFCMToken(String userId) async {
    try {
      await FCMService.initializeNotifications();
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) {
        debugPrint('⚠️ FCM token is null, cannot register');
        return;
      }
      await FirebaseDatabase.instance
          .ref()
          .child('handymen')
          .child(userId)
          .update({
        'fcmToken': token,
        'lastTokenUpdate': DateTime.now().toIso8601String(),
      });
      debugPrint('✅ FCM token registered for user: $userId');
    } catch (e) {
      debugPrint('❌ Error registering FCM token: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Account Profile'),
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        automaticallyImplyLeading: false, // Prevent back button
        actions: [
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: _isRefreshing ? null : _refreshHandymanData,
            tooltip: 'Check approval status',
          ),
          // Logout button
          IconButton(
            icon: const Icon(Icons.logout_outlined),
            onPressed: () {
              // Log out and go back to login screen
              Navigator.pushReplacementNamed(context, '/login');
            },
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _isRefreshing 
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(height: 16),
                Text(
                  'Checking account status...',
                  style: TextStyle(color: AppTheme.textBodyColor),
                ),
              ],
            ),
          )
        : RefreshIndicator(
            color: AppTheme.primaryColor,
            onRefresh: _refreshHandymanData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Account Pending Banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: AppTheme.warningColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.warningColor),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.pending_actions_outlined, color: AppTheme.warningColor),
                            const SizedBox(width: 8),
                            Text(
                              'ACCOUNT PENDING APPROVAL',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textHeadingColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your account is currently under review by our admin team. '
                          'You will be able to access all features once approved.',
                          style: TextStyle(color: AppTheme.textBodyColor),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _isRefreshing ? null : _refreshHandymanData,
                          icon: _isRefreshing 
                            ? SizedBox(
                                width: 16, 
                                height: 16, 
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppTheme.warningColor,
                                )
                              ) 
                            : Icon(Icons.refresh_outlined, color: AppTheme.warningColor),
                          label: Text('Check Status'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.warningColor,
                            side: BorderSide(color: AppTheme.warningColor),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Profile Information
                  Text(
                    'Profile Information',
                    style: TextStyle(
                      fontSize: 20, 
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  _buildProfileItem('Name', _handymanData['name'] ?? 'Not provided'),
                  _buildProfileItem('Email', _handymanData['email'] ?? 'Not provided'),
                  _buildProfileItem('Phone', _handymanData['phone'] ?? 'Not provided'),
                  _buildProfileItem('Expertise', 
                    _handymanData['expertise'] != null 
                      ? (_handymanData['expertise'] is List 
                          ? (_handymanData['expertise'] as List).join(', ')
                          : _handymanData['expertise'].toString())
                      : 'Not provided'
                  ),
                  _buildProfileItem('State', _handymanData['state'] ?? 'Not provided'),
                  _buildProfileItem('City', _handymanData['city'] ?? 'Not provided'),
                  _buildProfileItem('Account Status', 'Pending Approval', isHighlighted: true),
                  
                  const SizedBox(height: 24),
                  
                  // Contact Support Section
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: AppTheme.blueTintBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Need Help?',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'If you have any questions about your application status, please contact our support team:',
                          style: TextStyle(color: AppTheme.textBodyColor),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () {
                            // Implementation for email link
                          },
                          child: Text(
                            'support@handymanapp.com',
                            style: TextStyle(
                              color: AppTheme.secondaryColor,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }
  
  Widget _buildProfileItem(String label, String value, {bool isHighlighted = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: isHighlighted ? AppTheme.purpleTintBackground : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isHighlighted ? AppTheme.warningColor : Colors.grey.shade200,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.textBodyColor,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
                color: isHighlighted ? AppTheme.warningColor : AppTheme.textHeadingColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}