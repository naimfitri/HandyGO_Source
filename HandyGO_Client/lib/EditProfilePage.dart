import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'api_service.dart'; // Import ApiService
import 'dart:convert';

// Define the color scheme constants
class AppColors {
  // Primary Colors
  static const Color primary = Color(0xFF5C6BC0); // Indigo
  static const Color primaryLight = Color(0xFF8E99F3);
  static const Color primaryDark = Color(0xFF26418F);
  
  // Secondary Colors
  static const Color secondary = Color(0xFF26A69A); // Teal
  static const Color amber = Color(0xFFFFB74D); // Amber
  
  // Background Colors
  static const Color background = Color(0xFFF8F9FA); // Soft Light Grey
  static const Color surface = Color(0xFFFFFFFF); // Pure White
  
  // Text Colors
  static const Color textHeading = Color(0xFF333333); // Charcoal Grey
  static const Color textBody = Color(0xFF666666); // Medium Grey
  
  // Status Colors
  static const Color success = Color(0xFF66BB6A); // Green
  static const Color warning = Color(0xFFFFA726); // Orange
  static const Color error = Color(0xFFEF5350); // Red
}

class EditProfilePage extends StatefulWidget {
  final String userId;
  final String name;
  final String email;
  final String phone; // Add phone parameter

  const EditProfilePage({
    required this.userId,
    required this.name,
    required this.email,
    this.phone = '', // Default to empty string
    Key? key,
  }) : super(key: key);

  @override
  _EditProfilePageState createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _oldPasswordController;
  late TextEditingController _passwordController;
  bool _isLoading = true; // Start with loading state
  bool _obscureOldPassword = true;
  bool _obscureNewPassword = true;
  
  // Create an instance of the ApiService
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    // Initialize controllers with widget values as defaults
    _nameController = TextEditingController(text: widget.name);
    _emailController = TextEditingController(text: widget.email);
    _phoneController = TextEditingController(text: widget.phone);
    _oldPasswordController = TextEditingController();
    _passwordController = TextEditingController();
    
    // Fetch the latest user data from API
    _fetchUserData();
  }

  // Add method to fetch user data
  Future<void> _fetchUserData() async {
    try {
      final response = await _apiService.getUserData(widget.userId);
      
      if (response.statusCode == 200) {
        final userData = json.decode(response.body);
        
        setState(() {
          // Update controllers with fresh data
          _nameController.text = userData['name'] ?? widget.name;
          _emailController.text = userData['email'] ?? widget.email;
          
          // Ensure phone is converted to string (in case it's stored as numeric type)
          _phoneController.text = userData['phone']?.toString() ?? widget.phone;
          
          _isLoading = false;
        });
      } else {
        // If API call fails, use the data passed to the widget
        setState(() {
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not fetch latest user data.'),
            backgroundColor: AppColors.warning,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      // On error, use the data passed to the widget
      setState(() {
        _isLoading = false;
      });
      
      print('Error fetching user data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading user data: ${e.toString()}'),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose(); // Dispose phone controller
    _oldPasswordController.dispose(); // Dispose old password controller
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Use ApiService to update profile data
      final profileUpdateResponse = await _apiService.updateUserProfile(
        widget.userId,
        {
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'phone': _phoneController.text.trim(),
        },
      );

      if (profileUpdateResponse.statusCode != 200) {
        throw Exception('Failed to update profile: ${profileUpdateResponse.body}');
      }

      // Update password if provided
      if (_passwordController.text.isNotEmpty) {
        // Only proceed if old password is provided
        if (_oldPasswordController.text.isEmpty) {
          throw Exception("Please enter your current password to update to a new one");
        }
        
        final passwordUpdateResponse = await _apiService.updatePassword(
          widget.userId,
          _oldPasswordController.text.trim(),
          _passwordController.text.trim(),
        );
        
        if (passwordUpdateResponse.statusCode != 200) {
          throw Exception('Failed to update password: ${passwordUpdateResponse.body}');
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Profile updated successfully!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating profile: ${e.toString()}'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 1,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textHeading),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Text(
          "Edit Profile",
          style: TextStyle(
            color: AppColors.textHeading, 
            fontSize: 18, 
            fontWeight: FontWeight.w600
          ),
        ),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(20.0),
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 32),

                      // Section title
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Text(
                          "Personal Information",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textHeading,
                          ),
                        ),
                      ),

                      // Name Field
                      _buildFormField(
                        controller: _nameController,
                        label: "Full Name",
                        icon: Icons.person_outline,
                        validator: (value) =>
                            value == null || value.isEmpty ? "Please enter your name" : null,
                      ),
                      const SizedBox(height: 20),

                      // Email Field
                      _buildFormField(
                        controller: _emailController,
                        label: "Email Address",
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) =>
                            value == null || value.isEmpty ? "Please enter your email" : null,
                      ),
                      const SizedBox(height: 20),
                      
                      // Phone Field - add this new field
                      _buildFormField(
                        controller: _phoneController,
                        label: "Phone Number",
                        icon: Icons.phone_outlined,
                        prefix: "+60 ", // Add Malaysian country code prefix
                        keyboardType: TextInputType.phone,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return "Please enter your phone number";
                          }
                          // Remove the prefix if present for validation
                          final phoneNumber = value.startsWith('+60 ') ? 
                              value.substring(4) : value;
                          if (phoneNumber.isEmpty) {
                            return "Please enter your phone number";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Section title
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 12.0),
                        child: Text(
                          "Security",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textHeading,
                          ),
                        ),
                      ),

                      // Old Password Field - Add this new field
                      _buildFormField(
                        controller: _oldPasswordController,
                        label: "Current Password",
                        icon: Icons.lock_outline,
                        obscureText: _obscureOldPassword,
                        toggleObscure: () {
                          setState(() {
                            _obscureOldPassword = !_obscureOldPassword;
                          });
                        },
                      ),
                      const SizedBox(height: 20),

                      // Password Field
                      _buildFormField(
                        controller: _passwordController,
                        label: "New Password (optional)",
                        icon: Icons.lock_outline,
                        obscureText: _obscureNewPassword,
                        toggleObscure: () {
                          setState(() {
                            _obscureNewPassword = !_obscureNewPassword;
                          });
                        },
                      ),
                      
                      // Help text
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0, left: 8.0),
                        child: Text(
                          "Leave blank if you don't want to change the password",
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textBody,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 40),

                      // Update Button
                      Container(
                        width: double.infinity,
                        height: 54,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.3),
                              blurRadius: 8,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _updateProfile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            "Save Changes",
                            style: TextStyle(
                              fontSize: 16, 
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  // Helper method to build consistently styled form fields
  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    VoidCallback? toggleObscure,
    String? prefix, // Add prefix parameter
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: TextStyle(
        color: AppColors.textHeading,
        fontSize: 15,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppColors.textBody),
        prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
        prefixText: prefix, // Set the prefix text
        suffixIcon: toggleObscure != null ? IconButton(
          icon: Icon(
            obscureText ? Icons.visibility_off : Icons.visibility,
            color: AppColors.textBody.withOpacity(0.7),
            size: 20,
          ),
          onPressed: toggleObscure,
        ) : null,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.textBody.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.error, width: 2),
        ),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      ),
      validator: validator,
      cursorColor: AppColors.primary,
    );
  }
}
