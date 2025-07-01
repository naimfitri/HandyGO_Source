import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'EditProfilePage.dart';
import 'booking_completed.dart';
import 'AddressesPage.dart';
import 'wallet/WalletPage.dart';
import 'api_service.dart'; // Add this import

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

// Class to represent profile icon options
class ProfileIconOption {
  final IconData icon;
  final String label;
  
  ProfileIconOption({required this.icon, required this.label});
}

class ProfilePage extends StatefulWidget {
  final String userId;

  const ProfilePage({
    required this.userId,
    Key? key,
  }) : super(key: key);

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final ApiService _apiService = ApiService(); // Create ApiService instance
  String? _primaryAddress;
  bool _isLoadingAddress = true;
  double _walletBalance = 0.0;
  bool _isLoadingWallet = true;
  int _bookingCount = 0;
  bool _isLoadingBookings = true;
  bool _isUploadingImage = false;
  String? _profileImageUrl;
  
  // Add these new state variables to store the user's name and email
  String _userName = '';
  String _userEmail = '';
  bool _isLoadingUserData = true;
  
  // Selected profile icon
  IconData _selectedIcon = Icons.person;
  
  // Image picker instance
  final ImagePicker _picker = ImagePicker();
  
  // List of available profile icons
  final List<ProfileIconOption> _iconOptions = [
    ProfileIconOption(icon: Icons.person, label: 'Person'),
    ProfileIconOption(icon: Icons.face, label: 'Face'),
    ProfileIconOption(icon: Icons.emoji_people, label: 'Standing Person'),
    ProfileIconOption(icon: Icons.sentiment_satisfied_alt, label: 'Smiley'),
    ProfileIconOption(icon: Icons.sports, label: 'Active'),
    ProfileIconOption(icon: Icons.star, label: 'Star'),
    ProfileIconOption(icon: Icons.favorite, label: 'Heart'),
    ProfileIconOption(icon: Icons.home, label: 'Home'),
    ProfileIconOption(icon: Icons.work, label: 'Work'),
    ProfileIconOption(icon: Icons.pets, label: 'Pet'),
    ProfileIconOption(icon: Icons.directions_car, label: 'Car'),
    ProfileIconOption(icon: Icons.local_florist, label: 'Flower'),
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData(); // Add this to load user data first
    _loadPrimaryAddress();
    _loadBookingCount();
    _loadProfileImage();
    _loadWalletBalance();
  }
  
  // Add new method to load user data
  Future<void> _loadUserData() async {
    setState(() {
      _isLoadingUserData = true;
    });

    try {
      final response = await _apiService.getUserData(widget.userId);
      
      if (response.statusCode == 200) {
        final userData = json.decode(response.body);
        setState(() {
          _userName = userData['name'] ?? 'User';
          _userEmail = userData['email'] ?? 'No email';
          _isLoadingUserData = false;
        });
      } else {
        // Handle error
        setState(() {
          _userName = 'User';
          _userEmail = 'No email available';
          _isLoadingUserData = false;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not load user profile: ${response.reasonPhrase}'),
              backgroundColor: AppColors.warning,
            ),
          );
        }
      }
    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        _userName = 'User';
        _userEmail = 'No email available';
        _isLoadingUserData = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading profile: $e'),
            backgroundColor: AppColors.warning,
          ),
        );
      }
    }
  }
  
  Future<void> _loadPrimaryAddress() async {
    setState(() {
      _isLoadingAddress = true;
    });

    try {
      final response = await _apiService.getUserAddress(widget.userId);

      if (response.statusCode == 200) {
        final addressData = json.decode(response.body);
        
        // Check if we got meaningful address data
        final hasAddressData = addressData != null && 
            (addressData['buildingName']?.isNotEmpty == true || 
             addressData['streetName']?.isNotEmpty == true || 
             addressData['city']?.isNotEmpty == true);
        
        if (hasAddressData) {
          setState(() {
            _primaryAddress = _formatAddressFromData(addressData);
          });
        } else {
          setState(() {
            _primaryAddress = null; // Will show "No address added"
          });
        }
      } else {
        // Handle error response
        setState(() {
          _primaryAddress = null;
        });
        
        // Show error message if widget is still mounted
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not load address: ${response.reasonPhrase}'),
              backgroundColor: AppColors.warning,
              duration: Duration(seconds: 3),
              action: SnackBarAction(
                label: 'RETRY',
                textColor: Colors.white,
                onPressed: _loadPrimaryAddress,
              ),
            ),
          );
        }
      }
    } catch (e) {
      print('Error in _loadPrimaryAddress: $e');
      
      setState(() {
        _primaryAddress = null;
      });
      
      // Show a snackbar with the error only if the widget is still mounted
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not load address. Check your connection.'),
            backgroundColor: AppColors.warning,
            duration: Duration(seconds: 3),
            action: SnackBarAction(
              label: 'RETRY',
              textColor: Colors.white,
              onPressed: _loadPrimaryAddress,
            ),
          ),
        );
      }
    } finally {
      setState(() {
        _isLoadingAddress = false;
      });
    }
  }
  
  // New helper method to format address from API response
  String _formatAddressFromData(Map<String, dynamic> addressData) {
    final parts = [
      addressData['unitName'],
      addressData['buildingName'],
      addressData['streetName'],
      addressData['city'],
      addressData['postalCode'],
      addressData['country'],
    ];

    return parts.where((part) => part != null && part.toString().isNotEmpty)
        .join(', ');
  }

  // Keep the original _formatAddress method for compatibility
  String _formatAddress(Map<String, dynamic> address) {
    final parts = [
      address['unitName'],
      address['buildingName'],
      address['streetName'],
      address['city'],
      address['postalCode'],
      address['country'],
    ];

    return parts.where((part) => part != null && part.toString().isNotEmpty)
        .join(', ');
  }
  
  
  Future<void> _loadBookingCount() async {
    setState(() {
      _isLoadingBookings = true;
    });

    try {
      final response = await _apiService.getBookingCount(widget.userId);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _bookingCount = data['count'] ?? 0;
        });
      }
    } catch (e) {
      print('Error loading booking count: $e');
    } finally {
      setState(() {
        _isLoadingBookings = false;
      });
    }
  }
  
  // Add this method to load wallet balance
  Future<void> _loadWalletBalance() async {
    setState(() {
      _isLoadingWallet = true;
    });

    try {
      final response = await _apiService.getUserWallet(widget.userId);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _walletBalance = (data['balance'] ?? 0).toDouble();
        });
      }
    } catch (e) {
      print('Error loading wallet balance: $e');
    } finally {
      setState(() {
        _isLoadingWallet = false;
      });
    }
  }
  
  // Enhanced profile image loading with better error handling
  Future<void> _loadProfileImage() async {
    try {
      print('Loading profile image for user: ${widget.userId}');
      final result = await _apiService.fetchProfileImageUser(widget.userId);
      
      if (result['success'] == true && result['imageUrl'] != null) {
        print('Successfully retrieved image URL: ${result['imageUrl']}');
        setState(() {
          _profileImageUrl = result['imageUrl'];
        });
      } else {
        print('Failed to load profile image: ${result['error'] ?? 'Unknown error'}');
        
        // Try fallback method - get user data directly
        try {
          final userResponse = await _apiService.getUserData(widget.userId);
          if (userResponse.statusCode == 200) {
            final userData = json.decode(userResponse.body);
            if (userData['profileImage'] != null) {
              setState(() {
                _profileImageUrl = userData['profileImage'];
              });
              print('Loaded profile image from user data: $_profileImageUrl');
            }
          }
        } catch (innerError) {
          print('Error in fallback image loading: $innerError');
        }
      }
    } catch (e) {
      print('Error loading profile image: $e');
    }
  }
  
  // Show icon picker dialog
  void _showIconPickerDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Choose Profile Icon',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textHeading,
                  ),
                ),
                SizedBox(height: 16),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.5,
                  ),
                  child: GridView.builder(
                    shrinkWrap: true,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: _iconOptions.length,
                    itemBuilder: (context, index) {
                      final option = _iconOptions[index];
                      final isSelected = option.icon == _selectedIcon;
                      
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedIcon = option.icon;
                          });
                          Navigator.of(context).pop();
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary.withOpacity(0.15)
                                : AppColors.background,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.textBody.withOpacity(0.2),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                option.icon,
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.textBody,
                                size: 28,
                              ),
                              SizedBox(height: 4),
                              Text(
                                option.label,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.textBody,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                  ),
                  child: Text('Close'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  // Pick image from gallery or camera
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 80,
      );
      
      if (pickedFile != null) {
        try {
          File? croppedFile = await _cropImage(File(pickedFile.path));
          if (croppedFile != null) {
            _uploadProfileImage(croppedFile);
          } else {
            // If cropping fails, use the original image
            _uploadProfileImage(File(pickedFile.path));
          }
        } catch (e) {
          debugPrint('Error during image cropping: $e');
          // If cropping throws an error, use original image
          _uploadProfileImage(File(pickedFile.path));
        }
      }
    } catch (e) {
      print('Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting image: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
  
  // Crop picked image
  Future<File?> _cropImage(File imageFile) async {
    try {
      final CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: imageFile.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1), // Keep square ratio
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Profile Image',
            toolbarColor: AppColors.primary,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: 'Crop Profile Image',
            doneButtonTitle: 'Done',
            cancelButtonTitle: 'Cancel',
            aspectRatioLockEnabled: true,
          ),
          WebUiSettings(
            context: context,
          ),
        ],
      );

      if (croppedFile == null) return null;
      return File(croppedFile.path);
    } catch (e) {
      debugPrint('❌ Error cropping image: $e');
      // Return null instead of original file to signal error
      return null;
    }
  }
  
  // Upload profile image
  Future<void> _uploadProfileImage(File imageFile) async {
    setState(() {
      _isUploadingImage = true;
    });
    
    try {
      final result = await _apiService.uploadProfileImage(widget.userId, imageFile);
      
      if (result['success']) {
        setState(() {
          _profileImageUrl = result['imageUrl'];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Profile image updated successfully'),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload image: ${result['error']}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error uploading image: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      setState(() {
        _isUploadingImage = false;
      });
    }
  }
  
  // Show image source selection dialog
  void _showImageSourceDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Change Profile Picture',
            style: TextStyle(
              color: AppColors.textHeading,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.photo_camera, color: AppColors.primary),
                title: Text('Take a Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_library, color: AppColors.primary),
                title: Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              if (_profileImageUrl != null)
                ListTile(
                  leading: Icon(Icons.delete, color: AppColors.error),
                  title: Text('Remove Photo'),
                  onTap: () {
                    // Implement remove photo functionality
                    Navigator.pop(context);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  // Enhanced method to refresh all user data including name and email
  Future<void> _refreshAllUserData() async {
    if (!mounted) return;
    
    setState(() {
      _isLoadingUserData = true;
      _isLoadingAddress = true;
      _isLoadingWallet = true;
      _isLoadingBookings = true;
    });

    try {
      // Create a batch of Future requests to load everything in parallel
      await Future.wait([
        _loadUserData(),
        _loadPrimaryAddress(),
        _loadBookingCount(),
        _loadProfileImage(),
        _loadWalletBalance(),
      ]);
    } catch (e) {
      print('Error refreshing user data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error refreshing data. Please try again.'),
            backgroundColor: AppColors.warning,
          ),
        );
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text(
          'Profile',
          style: TextStyle(
            color: AppColors.textHeading,
            fontWeight: FontWeight.w600, 
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
        
      ),
      body: RefreshIndicator(
        onRefresh: _refreshAllUserData, // Use the new comprehensive refresh method
        color: AppColors.primary,
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(height: 20),
                
                // Profile Picture and Name - with the new color theme and icon selection
                Center(
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          Container(
                            height: 100,
                            width: 100,
                            decoration: BoxDecoration(
                              gradient: _profileImageUrl == null 
                                ? LinearGradient(
                                    colors: [AppColors.primary, AppColors.primaryLight],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                : null,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.3),
                                  blurRadius: 10,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: _isUploadingImage
                              ? CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  strokeWidth: 3,
                                )
                              : ClipOval(
                                  child: _profileImageUrl != null
                                    ? Image.network(
                                        _profileImageUrl!,
                                        fit: BoxFit.cover,
                                        width: 100,
                                        height: 100,
                                        errorBuilder: (context, error, stackTrace) {
                                          return _buildProfileFallback();
                                        },
                                      )
                                    : _buildProfileFallback(),
                                ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: InkWell(
                              onTap: _showImageSourceDialog,
                              child: Container(
                                padding: EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: AppColors.secondary,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 5,
                                      offset: Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      Text(
                        _userName,  // Replace widget.userName with _userName
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textHeading,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        _userEmail,  // Replace widget.userEmail with _userEmail
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textBody,
                        ),
                      ),
                      SizedBox(height: 20),
                      
                      // Edit Profile Button - Updated with theme
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EditProfilePage(
                                userId: widget.userId,
                                name: _userName,  // Update to use state variable
                                email: _userEmail,  // Update to use state variable
                              ),
                            ),
                          ).then((_) => _refreshAllUserData());  // Refresh data after returning from edit page
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          padding: EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                          minimumSize: Size(200, 45),
                          elevation: 0,
                        ),
                        child: Text(
                          'Edit Profile',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                SizedBox(height: 30),
                
                // Quick Action Tiles
                Row(
                  children: [
                    _buildSimpleActionTile(
                      'Completed Booking',
                      Icons.check_circle_outline,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => BookingCompletedPage(userId: widget.userId),
                          ),
                        );
                      },
                      AppColors.success,
                    ),
                    _buildSimpleActionTile(
                      'Wallet',
                      Icons.account_balance_wallet_outlined,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => WalletPage(
                              userId: widget.userId,
                              userName: _userName,
                              initialWalletBalance: _walletBalance,
                            ),
                          ),
                          );
                        },
                        AppColors.amber,
                    ),
                    
                    _buildSimpleActionTile(
                      'Profile Info',
                      Icons.person_outline,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EditProfilePage(
                              userId: widget.userId,
                              name: _userName,  // Update to use state variable
                              email: _userEmail,  // Update to use state variable
                            ),
                          ),
                        ).then((_) => _refreshAllUserData());  // Refresh data after returning
                      },
                      AppColors.primary,
                    ),
                    
                    _buildSimpleActionTile(
                      'Manage Address',
                      Icons.location_on_outlined,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AddressesPage(userId: widget.userId),
                          ),
                        ).then((_) => _loadPrimaryAddress());
                      },
                      AppColors.secondary,
                    ),
                  ],
                ),
                
                SizedBox(height: 35),
                
                // Address Section
                _buildAddressSection(),
                
                SizedBox(height: 30),
                
                // Logout Button
                Container(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      try {
                        await FirebaseAuth.instance.signOut();
                        Navigator.pushReplacementNamed(context, '/login');
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error logging out: $e'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                      }
                    },
                    icon: Icon(Icons.logout),
                    label: Text(
                      'Sign Out',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error.withOpacity(0.1),
                      foregroundColor: AppColors.error,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: AppColors.error.withOpacity(0.3)),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
                
                SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildSimpleActionTile(String label, IconData icon, VoidCallback onTap, Color color) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.1),
                    blurRadius: 5,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                icon, 
                color: color,
                size: 24,
              ),
            ),
            SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.textHeading,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildAddressSection() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AddressesPage(userId: widget.userId),
              ),
            ).then((_) => _loadPrimaryAddress());
          },
          child: Padding(
            padding: EdgeInsets.all(8),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.location_on,
                    color: AppColors.secondary,
                    size: 22,
                  ),
                ),
                SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Primary Address',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textHeading,
                        ),
                      ),
                      SizedBox(height: 4),
                      _isLoadingAddress
                        ? SizedBox(
                            height: 2,
                            width: 100,
                            child: LinearProgressIndicator(
                              backgroundColor: Colors.grey.shade200,
                              valueColor: AlwaysStoppedAnimation<Color>(AppColors.secondary),
                            ),
                          )
                        : Text(
                            _primaryAddress != null ? 'Address saved' : 'No address added',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textBody,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: AppColors.textBody.withOpacity(0.5),
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  // Helper method for profile picture fallback
  Widget _buildProfileFallback() {
    return Center(
      child: _userName.isNotEmpty  // Replace widget.userName with _userName 
        ? _selectedIcon != Icons.person
          ? Icon(
              _selectedIcon,
              size: 50,
              color: Colors.white,
            )
          : Text(
              _userName[0].toUpperCase(),  // Replace widget.userName with _userName
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            )
        : Icon(
            Icons.person,
            size: 50,
            color: Colors.white.withOpacity(0.9),
          ),
    );
  }
}
