import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart'; // Add this import
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'api_service.dart';
import 'ProfileEditPage.dart';
import 'PrivacyPolicyPage.dart';
import 'RatingPage.dart'; // Add this import

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

class ProfilePage extends StatefulWidget {
  final String userId;

  const ProfilePage({Key? key, required this.userId}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final ApiService _apiService = ApiService();
  final user = FirebaseAuth.instance.currentUser;
  final dbRef = FirebaseDatabase.instance.ref().child('handymen');
  final _imagePicker = ImagePicker();
  
  bool _isLoading = true;
  bool _isUploading = false;
  
  // Profile data
  String name = '';
  String email = '';
  String phone = '';
  String address = '';
  List<String> expertise = []; // Changed from String jobCategory
  String experience = '';
  List<String> skills = [];
  String profileImageUrl = '';
  double rating = 0.0;
  int completedJobs = 0;
  double totalEarnings = 0.0;
  
  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    setState(() {
      _isLoading = true;
      // Initialize with default values
      name = '';
      email = '';
      phone = '';
      address = '';
      expertise = []; // Changed from jobCategory
      experience = '';
      skills = [];
      profileImageUrl = '';
      rating = 0.0;
      completedJobs = 0;
      totalEarnings = 0.0;
    });
    
    try {
      // Get user email from Firebase Auth
      email = user?.email ?? '';
      
      // Get handyman profile from API
      final profileResult = await _apiService.getHandymanProfile(widget.userId);
      
      if (profileResult['success'] && profileResult['profile'] != null) {
        final profileData = profileResult['profile'];
        
        // Get the profile image URL
        String imageUrl = profileData['profileImage'] ?? '';
        debugPrint('⚠️ Profile image URL from API: $imageUrl');
        
        // If URL is empty or seems invalid, try fetching it directly
        if (imageUrl.isEmpty || !Uri.parse(imageUrl).isAbsolute) {
          debugPrint('⚠️ Profile image URL is empty or invalid, trying direct fetch');
          final imageResult = await _apiService.fetchProfileImage(widget.userId);
          
          if (imageResult['success'] && imageResult['imageUrl'] != null) {
            imageUrl = imageResult['imageUrl'];
            debugPrint('⚠️ Got profile image URL via direct fetch: $imageUrl');
          }
        }
        
        setState(() {
          name = profileData['name'] ?? '';
          phone = profileData['phone'] ?? '';
          address = profileData['address'] ?? '';
          
          // Parse expertise from API response
          if (profileData['expertise'] != null) {
            if (profileData['expertise'] is List) {
              expertise = List<String>.from(profileData['expertise']);
            } else if (profileData['expertise'] is String) {
              expertise = [profileData['expertise']];
            }
          }
          
          experience = profileData['experience'] ?? '';
          profileImageUrl = imageUrl;
          
          // Parse skills if available
          if (profileData['skills'] != null) {
            if (profileData['skills'] is List) {
              skills = List<String>.from(profileData['skills']);
            } else if (profileData['skills'] is Map) {
              skills = (profileData['skills'] as Map).values.map((e) => e.toString()).toList();
            } else if (profileData['skills'] is String) {
              skills = [profileData['skills'] as String];
            }
          }
        });
      } else {
        debugPrint('⚠️ Failed to get profile data: ${profileResult['error']}');
        
        // Fallback to Firebase direct access if API fails
        try {
          final snapshot = await dbRef.child(widget.userId).get();
          
          if (snapshot.exists && snapshot.value != null) {
            Map<String, dynamic> data = Map<String, dynamic>.from(snapshot.value as Map);
            
            setState(() {
              name = data['name'] ?? '';
              phone = data['phone'] ?? '';
              address = data['address'] ?? '';
              
              // Parse expertise from Realtime DB
              if (data['expertise'] != null) {
                if (data['expertise'] is List) {
                  expertise = List<String>.from(data['expertise']);
                } else if (data['expertise'] is String) {
                  expertise = [data['expertise']];
                } else if (data['expertise'] is Map) {
                  expertise = (data['expertise'] as Map).values.map((e) => e.toString()).toList();
                }
              }
              
              experience = data['experience'] ?? '';
              profileImageUrl = data['profileImage'] ?? '';
              
              // Parse skills if available
              if (data['skills'] != null) {
                if (data['skills'] is List) {
                  skills = List<String>.from(data['skills']);
                } else if (data['skills'] is Map) {
                  skills = (data['skills'] as Map).values.map((e) => e.toString()).toList();
                } else if (data['skills'] is String) {
                  skills = [data['skills'] as String];
                }
              }
            });
          }
        } catch (dbError) {
          debugPrint('⚠️ Firebase fallback error: $dbError');
        }
      }
      
      // Get stats data from API
      await _fetchHandymanStats();
    } catch (e) {
      debugPrint('⚠️ Error in _loadProfileData: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load profile data: $e'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchHandymanStats() async {
    try {
      final result = await _apiService.getHandymanJobStats(widget.userId);
      
      if (result['success'] == true) {
        setState(() {
          completedJobs = result['completedJobs'] ?? 0;
          totalEarnings = (result['totalRevenue'] ?? 0.0).toDouble();
        });
      } else {
        debugPrint('⚠️ API returned error: ${result['error']}');
      }
      
      // Fetch ratings separately
      final ratingsResult = await _apiService.getHandymanRatings(widget.userId);
      if (ratingsResult['success'] == true) {
        setState(() {
          rating = ratingsResult['averageRating']?.toDouble() ?? 0.0;
        });
        debugPrint('✅ Fetched rating: $rating');
      } else {
        debugPrint('⚠️ Error fetching ratings: ${ratingsResult['error']}');
      }
    } catch (e) {
      debugPrint('⚠️ Error fetching handyman stats: $e');
    }
  }

  Future<void> _updateProfileImage() async {
    try {
      // Show the image source selection dialog
      final ImageSource? source = await showModalBottomSheet<ImageSource>(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (BuildContext context) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Select Image Source',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textHeadingColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildImageSourceOption(
                        context,
                        ImageSource.camera,
                        Icons.camera_alt_outlined,
                        'Camera',
                      ),
                      _buildImageSourceOption(
                        context,
                        ImageSource.gallery,
                        Icons.photo_library_outlined,
                        'Gallery',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
      );

      if (source == null) return;
      
      // Get image from selected source
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 80,
      );
      
      if (image == null) return;
      
      // Add crop step before uploading
      final croppedFile = await _cropImage(File(image.path));
      
      // If user canceled cropping, exit the function
      if (croppedFile == null) return;
      
      setState(() {
        _isUploading = true;
      });
      
      try {
        // Use the API service to upload the cropped image
        final result = await _apiService.uploadProfileImage(widget.userId, croppedFile);
        
        if (result['success'] && result['imageUrl'] != null) {
          final downloadUrl = result['imageUrl'];
          
          setState(() {
            profileImageUrl = downloadUrl;
            _isUploading = false;  // Add this line to stop the loading animation
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile image updated successfully'),
              backgroundColor: AppTheme.successColor,
            ),
          );
        } else {
          throw Exception(result['error'] ?? 'Failed to upload image');
        }
      } catch (e) {
        // Fallback to direct Firebase upload if API fails
        debugPrint('⚠️ API upload failed: $e. Falling back to direct upload...');
        
        // Upload to Firebase Storage with the correct path and naming convention
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('profile_handyman')
            .child('${widget.userId}.jpg');
        
        await storageRef.putFile(croppedFile);
        
        // Get download URL
        final downloadUrl = await storageRef.getDownloadURL();
        
        // Update image URL via API
        final result = await _apiService.updateProfileImage(widget.userId, downloadUrl);
        
        if (result['success']) {
          setState(() {
            profileImageUrl = downloadUrl;
            _isUploading = false;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Profile image updated'),
              backgroundColor: AppTheme.successColor,
            ),
          );
        } else {
          // Fallback to direct Firebase update if API fails
          await dbRef.child(widget.userId).update({
            'profileImage': downloadUrl,
          });
          
          setState(() {
            profileImageUrl = downloadUrl;
            _isUploading = false;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile image updated (Firebase fallback)'),
              backgroundColor: AppTheme.successColor,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error updating profile image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update profile image: $e'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      setState(() {
        _isUploading = false;  // Make sure this is always called to reset loading state
      });
    }
  }
  
  // Update the _cropImage method to use image_cropper 9.1.0
  Future<File?> _cropImage(File imageFile) async {
    try {
      final CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: imageFile.path,
        // Remove cropStyle parameter as it's not supported in your version
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1), // Keep square ratio
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Profile Image',
            toolbarColor: AppTheme.primaryColor,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
            hideBottomControls: false,
            showCropGrid: true,
            cropFrameColor: AppTheme.primaryColor,
            aspectRatioPresets: [
              CropAspectRatioPreset.square,
            ],
          ),
          IOSUiSettings(
            title: 'Crop Profile Image',
            doneButtonTitle: 'Done',
            cancelButtonTitle: 'Cancel',
            aspectRatioLockEnabled: true,
            aspectRatioPickerButtonHidden: true,
            aspectRatioPresets: [
              CropAspectRatioPreset.square,
            ],
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
      return imageFile; // Return original file if cropping fails
    }
  }

  // Helper method to build image source selection buttons
  Widget _buildImageSourceOption(
    BuildContext context,
    ImageSource source,
    IconData icon,
    String label,
  ) {
    return InkWell(
      onTap: () => Navigator.of(context).pop(source),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.blueTintBackground,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: AppTheme.primaryColor,
              size: 36,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditProfileDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileEditPage(
          userId: widget.userId,
          onProfileUpdated: () {
            _loadProfileData(); // Refresh data after update
          },
        ),
      ),
    );
  }

  Widget _buildListTile(IconData icon, String title, {String? subtitle, VoidCallback? onTap}) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppTheme.blueTintBackground,
        radius: 20,
        child: Icon(icon, color: AppTheme.primaryColor, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: AppTheme.textHeadingColor,
        ),
      ),
      subtitle: subtitle != null ? Text(
        subtitle,
        style: const TextStyle(
          color: AppTheme.textBodyColor,
          fontSize: 14,
        ),
      ) : null,
      trailing: onTap != null ? const Icon(
        Icons.arrow_forward_ios,
        color: AppTheme.textBodyColor,
        size: 16,
      ) : null,
      onTap: onTap,
    );
  }

  Widget _buildProfileImage() {
    debugPrint('⚠️ Building profile image with URL: $profileImageUrl');
    
    // Function to validate if URL is well-formed
    bool isValidUrl(String url) {
      if (url.isEmpty) return false;
      
      try {
        final uri = Uri.parse(url);
        return uri.isAbsolute;
      } catch (e) {
        return false;
      }
    }

    // Generate a cache-busting URL if it's a Firebase Storage URL
    String getFirebaseImageUrl(String url) {
      if (url.contains('firebasestorage') || url.contains('storage.googleapis.com')) {
        // Add a token parameter to avoid caching issues
        return '$url?alt=media&token=${DateTime.now().millisecondsSinceEpoch}';
      }
      return url;
    }
    
    if (_isUploading) {
      return const CircularProgressIndicator(
        color: Colors.white,
        strokeWidth: 2,
      );
    } else if (profileImageUrl.isNotEmpty && isValidUrl(profileImageUrl)) {
      // Apply the Firebase specific URL processing
      final imageUrl = getFirebaseImageUrl(profileImageUrl);
      
      debugPrint('⚠️ Loading image with processed URL: $imageUrl');
      
      return CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        placeholder: (context, url) => const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white,
          ),
        ),
        errorWidget: (context, url, error) {
          debugPrint('❌ Error loading image from URL: $url, Error: $error');
          return Container(
            color: AppTheme.purpleTintBackground,
            child: const Icon(
              Icons.person,
              size: 60,
              color: AppTheme.primaryColor,
            ),
          );
        },
        // Add these additional parameters
        memCacheWidth: 300, // Set reasonable memory cache size
        memCacheHeight: 300,
        httpHeaders: const {
          'Access-Control-Allow-Origin': '*', // Help with CORS
        },
      );
    } else {
      // Show placeholder when no valid URL
      return Container(
        color: AppTheme.purpleTintBackground,
        child: const Icon(
          Icons.person,
          size: 60,
          color: AppTheme.primaryColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
                'My Profile',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 24, // You can adjust size as needed
                ),
              ),
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppTheme.primaryColor,
              ),
            )
          : RefreshIndicator(
              color: AppTheme.primaryColor,
              onRefresh: _loadProfileData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Profile Header
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppTheme.primaryColor, AppTheme.secondaryColor.withOpacity(0.8)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(24),
                          bottomRight: Radius.circular(24),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Stack(
                            children: [
                              // Profile Image
                              GestureDetector(
                                onTap: _updateProfileImage,
                                child: Container(
                                  height: 120,
                                  width: 120,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 4,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 8,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: ClipOval(child: _buildProfileImage()),
                                ),
                              ),
                              // Edit Icon
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  height: 36,
                                  width: 36,
                                  decoration: BoxDecoration(
                                    color: AppTheme.secondaryColor,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 5,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt_outlined,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Center(
                            child: Text(
                              expertise.isNotEmpty ? expertise.join(', ') : 'No expertise listed',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 16,
                              ),
                              textAlign: TextAlign.center, // optional: ensures text inside is also centered
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.star,
                                color: Colors.amber,
                                size: 20,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$rating',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                ' • $completedJobs jobs',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _showEditProfileDialog,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppTheme.primaryColor,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              elevation: 3,
                            ),
                            child: const Text(
                              'Edit Profile',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Stats cards
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              'Total Earnings',
                              'RM ${totalEarnings.toStringAsFixed(2)}',
                              Icons.monetization_on_outlined,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildStatCard(
                              'Jobs Completed',
                              completedJobs.toString(),
                              Icons.check_circle_outline,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Add new Stats row for ratings
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => RatingPage(
                                handymanId: widget.userId,
                                handymanName: name,
                              ),
                            ),
                          );
                        },
                        child: Container(
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
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: AppTheme.purpleTintBackground,
                                radius: 24,
                                child: Icon(Icons.star_rounded, color: Colors.amber, size: 30),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '$rating/5.0',
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.textHeadingColor,
                                      ),
                                    ),
                                    const Text(
                                      'View all ratings and reviews',
                                      style: TextStyle(
                                        color: AppTheme.textBodyColor,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.arrow_forward_ios,
                                color: AppTheme.textBodyColor,
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    // Settings section
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                child: Row(
                                  children: [
                                    const CircleAvatar(
                                      backgroundColor: AppTheme.blueTintBackground,
                                      radius: 18,
                                      child: Icon(
                                        Icons.settings_outlined,
                                        color: AppTheme.primaryColor,
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Settings',
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.textHeadingColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Divider(),
                              _buildListTile(
                                Icons.privacy_tip_outlined,
                                'Privacy Policy',
                                onTap: () {
                                  // Navigate to privacy policy
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const PrivacyPolicyPage()),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    // Logout button
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await FirebaseAuth.instance.signOut();
                          Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
                        },
                        icon: const Icon(Icons.logout_outlined),
                        label: const Text(
                          'Sign Out',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.warningColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 3,
                        ),
                      ),
                    ),
                    
                    
                      
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Container(
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
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      child: Column(
        children: [
          CircleAvatar(
            backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
            radius: 24,
            child: Icon(icon, color: AppTheme.primaryColor, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textHeadingColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textBodyColor,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
