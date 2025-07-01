import 'package:flutter/material.dart';
import 'HandymanHomePage.dart';
import 'api_service.dart';
import 'handyman_restricted_profile_page.dart';
import 'services/location_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_database/firebase_database.dart';
import 'services/fcm_service.dart';

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

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  final ApiService _apiService = ApiService();

  Future<void> _loginUser() async {
    if (_formKey.currentState!.validate()) {
      FocusScope.of(context).unfocus();
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        final result = await _apiService.loginHandyman(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );

        if (result['success']) {
          // Get handyman data from result
          final handymanId = result['handymanId'];
          final handymanData = result['handymanData'];
          
          // Check handyman status and navigate accordingly
          if (handymanData['status'] == 'pending') {
            // For pending accounts, only allow access to profile page
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => HandymanRestrictedProfilePage(
                  userId: handymanId,
                  handymanData: handymanData,
                ),
              ),
            );
          } else if (handymanData['status'] == 'active') {

            // Register FCM token for this user (you'll need to add this method)
            await _registerFCMToken(handymanId);

            // Remove automatic location tracking start
            // Location tracking should only start when user goes online
            // LocationService().startLocationTracking(handymanId).then((success) {
            //   debugPrint('📍 Location tracking started: $success');
            // });

            // Full access for active accounts - navigate immediately
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => HandymanHomePage(userId: handymanId),
              ),
            );
          } else {
            setState(() {
              _errorMessage = 'Your account is not active. Please contact support.';
            });
          }
        } else {
          setState(() {
            _errorMessage = result['error'];
          });
        }
      } catch (e) {
        debugPrint('❌ Unexpected error: $e');
        setState(() {
          _errorMessage = 'Unexpected error occurred. Please try again.';
        });
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Add this method to register the FCM token
  Future<void> _registerFCMToken(String userId) async {
    try {
      // Initialize notifications since we now have a logged-in user
      await FCMService.initializeNotifications();
      
      // Get FCM token
      final token = await FirebaseMessaging.instance.getToken();
      
      if (token == null) {
        debugPrint('⚠️ FCM token is null, cannot register');
        return;
      }
      
      // Save to Firebase Realtime Database
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
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // App Logo / Icon
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppTheme.blueTintBackground,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withOpacity(0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      )
                    ],
                  ),
                  child: Icon(
                    Icons.home_repair_service_outlined,
                    size: 52,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 32),
                
                // Welcome Text
                Text(
                  "Welcome Back!",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "Login to continue your work",
                  style: TextStyle(
                    fontSize: 16,
                    color: AppTheme.textBodyColor,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 32),
                
                // Login Form
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withOpacity(0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      )
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(28.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Email label
                          const Padding(
                            padding: EdgeInsets.only(left: 8, bottom: 8),
                            child: Text(
                              'Email Address',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textHeadingColor,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          // Email input
                          _buildInputField(
                            label: 'Enter your email',
                            icon: Icons.email_outlined,
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) =>
                                value == null || value.isEmpty 
                                    ? 'Please enter your email' 
                                    : (!value.contains('@') 
                                        ? 'Please enter a valid email' 
                                        : null),
                          ),
                          const SizedBox(height: 20),
                          
                          // Password label
                          const Padding(
                            padding: EdgeInsets.only(left: 8, bottom: 8),
                            child: Text(
                              'Password',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textHeadingColor,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          // Password input
                          _buildInputField(
                            label: 'Enter your password',
                            icon: Icons.lock_outline_rounded,
                            controller: _passwordController,
                            obscureText: true,
                            validator: (value) =>
                                value == null || value.isEmpty 
                                    ? 'Please enter your password' 
                                    : null,
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Error message
                          if (_errorMessage != null)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.warningColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppTheme.warningColor.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.error_outline_rounded,
                                    color: AppTheme.warningColor,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: TextStyle(
                                        color: AppTheme.warningColor.withOpacity(0.8),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          
                          // Login button
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _loginUser,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: AppTheme.primaryColor.withOpacity(0.6),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Text(
                                          'Login',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.2),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.arrow_forward_rounded,
                                            size: 16,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                // Register link
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account?",
                      style: TextStyle(
                        color: AppTheme.textBodyColor,
                        fontSize: 15,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pushReplacementNamed(context, '/register');
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.secondaryColor,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: const Text(
                        "Register here",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(color: AppTheme.textHeadingColor),
      decoration: InputDecoration(
        hintText: label,
        hintStyle: TextStyle(color: AppTheme.textBodyColor.withOpacity(0.5)),
        prefixIcon: Container(
          margin: const EdgeInsets.only(right: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.blueTintBackground,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              bottomLeft: Radius.circular(12),
              topRight: Radius.circular(4),
              bottomRight: Radius.circular(4),
            ),
          ),
          child: Icon(
            icon, 
            color: AppTheme.primaryColor,
            size: 20,
          ),
        ),
        filled: true,
        fillColor: AppTheme.backgroundColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: AppTheme.primaryColor.withOpacity(0.1),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: AppTheme.primaryColor.withOpacity(0.4),
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: AppTheme.warningColor.withOpacity(0.5),
            width: 1,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: AppTheme.warningColor,
            width: 1.5,
          ),
        ),
      ),
    );
  }
}
