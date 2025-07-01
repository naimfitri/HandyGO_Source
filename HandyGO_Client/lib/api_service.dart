import 'dart:convert';
import 'dart:io';
import 'dart:math'; // Add this import for the min function
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http_parser/http_parser.dart';
import 'package:firebase_storage/firebase_storage.dart';

class ApiService {
  // Base URL for API
  static const String baseUrl = 'https://handygo-api.onrender.com';
  static const String notiUrl = 'https://handygo-api.onrender.com';

  // Address-related API calls
  Future<http.Response> addAddress(String userId, Map<String, dynamic> addressData) async {
    final uri = Uri.parse('$baseUrl/api/user/add-address');
    final requestData = {
      'userId': userId,
      'address': addressData,
    };

    return await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode(requestData),
    );
  }

  Future<http.Response> updateAddress(String userId, String addressId, Map<String, dynamic> addressData) async {
    final uri = Uri.parse('$baseUrl/api/user/update-address');
    final requestData = {
      'userId': userId,
      'addressId': addressId,
      'address': addressData,
    };

    return await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode(requestData),
    );
  }

  Future<http.Response> setPrimaryAddress(String userId, String addressId) async {
    final uri = Uri.parse('$baseUrl/api/user/set-primary-address');
    final requestData = {
      'userId': userId,
      'addressId': addressId,
    };

    return await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode(requestData),
    );
  }

  Future<http.Response> deleteAddress(String userId, String addressId) async {
    final uri = Uri.parse('$baseUrl/api/user/delete-address');
    final requestData = {
      'userId': userId,
      'addressId': addressId,
    };

    return await http.delete(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode(requestData),
    );
  }

  // User-related API calls
  Future<http.Response> getUserData(String userId) async {
    return await http.get(
      Uri.parse('$baseUrl/api/user/user/$userId'),
    );
  }

  Future<http.Response> getUserAddress(String userId) {
    return http.get(Uri.parse('$baseUrl/api/user/users/$userId/address'));
  }


  // Handyman-related API calls
  Future<http.Response> getHandymen(String expertise, {String? city}) {
    String endpoint = '$baseUrl/api/user/handymen?expertise=${Uri.encodeComponent(expertise)}';
    if (city != null && city.isNotEmpty) {
      endpoint += '&city=${Uri.encodeComponent(city)}';
    }

    return http.get(Uri.parse(endpoint));
  }

  Future<http.Response> getHandymanReviews(String handymanId) {
    return http.get(
      Uri.parse('$baseUrl/api/user/handyman-reviews/$handymanId'),
    );
  }

  Future<http.Response> submitReview({
    required String handymanId, 
    required int rating, 
    String? review,
    String? userId,
    String? userName,
    String? bookingId,
  }) {
    return http.post(
      Uri.parse('$baseUrl/api/user/submit-review'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'handymanId': handymanId,
        'rating': rating,
        'review': review ?? '',
        'userId': userId,
        'userName': userName,
        'bookingId': bookingId,
      }),
    );
  }

  Future<http.Response> getHandymanSlots(String handymanId) {
    print('Calling getHandymanSlots API for handymanId: $handymanId');
    final url = Uri.parse('$baseUrl/api/user/handyman-slots?UserId=$handymanId');
    return http.get(url).then((response) {
      print('Handyman slots response: ${response.statusCode} - ${response.body.substring(0, min(100, response.body.length))}...');
      return response;
    }).catchError((error) {
      print('Error in getHandymanSlots: $error');
      throw error;
    });
  }

  Future<http.Response> getHandymanJobs(String handymanId) {
    return http.get(
      Uri.parse('$baseUrl/api/user/handyman-jobs?handymanId=$handymanId'),
    );
  }

  Future<http.Response> getHandymanAvailability(String handymanId) {
    return http.get(
      Uri.parse('$baseUrl/api/user/handyman-availability/$handymanId'),
    );
  }

  // Booking-related API calls
  Future<http.Response> getUserBookings(String userId) {
    return http.get(
      Uri.parse('$baseUrl/api/user/user-bookings/$userId'),
    );
  }

  Future<http.Response> getUserWallet(String userId) {
    return http.get(
      Uri.parse('$baseUrl/api/user/user-wallet/$userId'),
    );
  }

  Future<http.Response> getCompletedBookings(String userId) {
    return http.get(
      Uri.parse('$baseUrl/api/user/bookings/completed/$userId'),
    );
  }

  // Booking creation and management
  Future<http.Response> getGlobalSettings() {
    return http.get(
      Uri.parse('$baseUrl/api/user/global-settings/fare'),
    );
  }
  
  Future<http.Response> createBookingWithFee(Map<String, dynamic> bookingData) {
    return http.post(
      Uri.parse('$baseUrl/api/user/create-booking-with-fee'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(bookingData),
    );
  }
  
  Future<http.Response> getHandyman(String handymanId) {
    return http.get(
      Uri.parse('$baseUrl/api/user/handyman/$handymanId'),
    );
  }
  
  Future<Map<String, dynamic>> fetchHandymanDetails(String handymanId) async {
    try {
      final response = await getHandyman(handymanId);
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw 'Failed to fetch handyman details: ${response.statusCode}';
      }
    } catch (e) {
      print('Error fetching handyman details: $e');
      rethrow;
    }
  }

  // Booking details methods
  Future<http.Response> getBookingDetails(String bookingId) {
    return http.get(
      Uri.parse('$baseUrl/api/user/booking/$bookingId'),
    );
  }
  
  Future<http.Response> cancelBooking(String bookingId, String userId) {
    return http.post(
      Uri.parse('$baseUrl/api/user/cancel-booking/$bookingId'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'user_id': userId}),
    );
  }

  // Add this method to get handyman location
  Future<http.Response> getHandymanLocation(String handymanId) {
    return http.get(
      Uri.parse('$baseUrl/api/user/handyman-location/$handymanId'),
    );
  }

  // Invoice and payment methods
  Future<http.Response> getInvoiceDetails(String bookingId) {
    return http.get(
      Uri.parse('$baseUrl/api/user/invoice/$bookingId'),
    );
  }
  
  Future<http.Response> getPaymentDetails(String bookingId) {
    return http.get(
      Uri.parse('$baseUrl/api/user/payment/$bookingId'),
    );
  }

  Future<http.Response> getRating(String handymanId, String bookingId) {
    return http.get(
      Uri.parse('$baseUrl/api/user/ratings/$handymanId/$bookingId'),
    );
  }
  
  Future<http.Response> submitRating({
    required String handymanId,
    required String bookingId,
    required String userId,
    required double rating,
    required String review,
    String? userName,
  }) {
    return http.post(
      Uri.parse('$baseUrl/api/user/ratings/submit'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'handymanId': handymanId,
        'bookingId': bookingId,
        'userId': userId,
        'rating': rating,
        'review': review,
        'userName': userName ?? 'Anonymous',
      }),
    );
  }

  // Payment processing
  Future<http.Response> processPayment({
    required String userId,
    required String bookingId,
    required String handymanId,
    required double amount,
  }) {
    return http.post(
      Uri.parse('$baseUrl/api/user/process-payment'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'userId': userId,
        'bookingId': bookingId,
        'handymanId': handymanId, 
        'amount': amount,
      }),
    );
  }

  // Location-related API calls
  Future<http.Response> saveLocation(Map<String, dynamic> addressData) {
    return http.post(
      Uri.parse('$baseUrl/api/user/save-location'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(addressData),
    ).timeout(const Duration(seconds: 10));
  }

  // Authentication methods
  Future<http.Response> login(String email, String password) {
    return http.post(
      Uri.parse('$baseUrl/api/user/login'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'email': email.trim(),
        'password': password.trim(),
      }),
    ).timeout(const Duration(seconds: 10));
  }

  // User registration
  Future<http.Response> register(String name, String email, String password, [String? phone]) {
    return http.post(
      Uri.parse('$baseUrl/api/user/register'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'name': name.trim(),
        'email': email.trim(),
        'password': password.trim(),
        'phone': phone?.trim() ?? '',  // Add the phone parameter
      }),
    ).timeout(const Duration(seconds: 10));
  }

  // Notification-related methods
  Future<http.Response> registerNotificationToken(String userId, String token, String userType) {
    return http.post(
      Uri.parse('$notiUrl/api/user/register-notification-token'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'userId': userId,
        'token': token,
        'userType': userType
      }),
    );
  }

  // Booking count method
  Future<http.Response> getBookingCount(String userId) {
    return http.get(
      Uri.parse('$baseUrl/api/user/bookings/count/$userId'),
    );
  }

  /// Fetches a profile image for a handyman from Firebase Storage via the backend API
  /// Returns a map with 'success' flag and 'imageUrl' if successful
  Future<Map<String, dynamic>> fetchProfileImageHandyman(String handymanId) async {
    try {
      debugPrint('⚠️ Fetching profile image for handyman: $handymanId');
      
      // First try the backend endpoint that handles Firebase Storage
      final response = await http.get(
        Uri.parse('$baseUrl/api/user/images_handyman/$handymanId'),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        
        if (responseBody['success'] == true && responseBody['imageUrl'] != null) {
          debugPrint('✅ Successfully fetched profile image from backend');
          return {
            'success': true,
            'imageUrl': responseBody['imageUrl'],
            'fromDatabase': responseBody['fromDatabase'] ?? false,
          };
        }
      }
      
      debugPrint('⚠️ Could not fetch image from backend API, using default URL');
      
      // If backend fails, use a direct URL (fallback method)
      final String directUrl = 'https://firebasestorage.googleapis.com/v0/b/handygo-b6885.appspot.com/o/profile_handyman%2F$handymanId.jpg?alt=media';
      
      return {
        'success': true,
        'imageUrl': directUrl,
        'fromDirect': true,
      };
    } catch (e) {
      debugPrint('❌ Error fetching profile image: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Get handyman profile image URL with fallback to default image
  String getHandymanProfileImageUrl(String handymanId) {
    // Use a default avatar image instead of trying to access potentially non-existent images
    return 'https://ui-avatars.com/api/?name=$handymanId&background=random&color=fff&size=128';
    
    // The previous approach was returning 404s:
    // return 'https://firebasestorage.googleapis.com/v0/b/handygo-b6885.appspot.com/o/profile_handyman%2F$handymanId.jpg?alt=media';
  }

  // Upload profile image for a handyman
  Future<Map<String, dynamic>> uploadProfileImage(String userId, File imageFile) async {
    try {
      // Determine the correct MIME type based on file extension
      final String extension = imageFile.path.split('.').last.toLowerCase();
      final String mimeType = _getMimeType(extension);
      
      debugPrint('⚠️ Uploading image with MIME type: $mimeType');
      
      // Create a multipart request to send the file
      var request = http.MultipartRequest(
        'POST', 
        Uri.parse('$baseUrl/api/user/users/$userId/upload-image')
      );
      
      // Add the file to the request
      final fileStream = http.ByteStream(imageFile.openRead());
      final fileLength = await imageFile.length();
      
      final multipartFile = http.MultipartFile(
        'image', 
        fileStream, 
        fileLength,
        filename: '$userId.jpg',
        contentType: MediaType.parse(mimeType), // Explicitly set content type
      );
      
      request.files.add(multipartFile);
      
      // Send the request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      debugPrint('⚠️ Image upload API response: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        return {
          'success': true,
          'imageUrl': responseBody['imageUrl'],
          'message': responseBody['message'] ?? 'Image uploaded successfully',
        };
      } else {
        // If the backend API fails, return error
        debugPrint('⚠️ API upload failed: ${response.statusCode}');
        return {
          'success': false,
          'error': 'Failed to upload image: ${response.reasonPhrase}',
        };
      }
    } catch (e) {
      debugPrint('❌ Error in uploadProfileImage: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
  
  // Helper method to update profile with image URL
  Future<Map<String, dynamic>> updateProfileImage(String userId, String imageUrl) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/user/update-profile-image'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': userId,
          'imageUrl': imageUrl,
        }),
      );
      
      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': 'Profile image updated successfully',
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to update profile image',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
  
  // Helper method to determine MIME type from file extension
  String _getMimeType(String extension) {
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'bmp':
        return 'image/bmp';
      default:
        return 'image/jpeg'; // Default to JPEG for unknown types
    }
  }
  
  // Fetch user profile image
  Future<Map<String, dynamic>> fetchProfileImageUser(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/user/images/$userId'),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'imageUrl': data['imageUrl'],
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to fetch profile image',
        };
      }
    } catch (e) {
      debugPrint('Error fetching profile image: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // Add this method to fetch handyman details
  Future<http.Response> getHandymanDetails(String handymanId) {
    return http.get(Uri.parse('$baseUrl/api/user/handyman/$handymanId'));
  }

  // Add new method for confirming bookings
  Future<http.Response> confirmBooking(String bookingId, String userId, bool termsAccepted) {
    final Map<String, dynamic> requestData = {
      'userId': userId,
      'bookingId': bookingId,
      'status': 'confirmed',
      'termsAccepted': termsAccepted,
      'timestamp': DateTime.now().toIso8601String(),
      'paymentMethod': 'wallet', // Add payment method
      'hasMaterials': false, // Include materials flag
      'approved': true // Add approval status
    };
    
    print('Sending booking confirmation: ${json.encode(requestData)}');
    
    return http.post(
      Uri.parse('$baseUrl/api/user/confirm-booking'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(requestData),
    );
  }

  Future<http.Response> getAllJobs() {
    return http.get(
      Uri.parse('$baseUrl/api/user/jobs'),
    ).catchError((error) {
      print('Error in getAllJobs: $error');
      // Return a default response with empty jobs to avoid breaking the UI
      return http.Response(json.encode({}), 200);
    });
  }

  Future<http.Response> getHandymanJobsCompleted(String handymanId) {
    return http.get(
      Uri.parse('$baseUrl/api/user/handyman-jobs/$handymanId'), // Correct path usage
    ).catchError((error) {
      print('Error in getHandymanJobsCompleted: $error');
      return getAllJobs();
    });
  }

  // Update user profile
  Future<http.Response> updateUserProfile(String userId, Map<String, dynamic> updateData) {
    return http.post(
      Uri.parse('$baseUrl/api/user/update-profile'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'userId': userId,
        ...updateData,
      }),
    );
  }
  
  // Update user password
  Future<http.Response> updatePassword(String userId, String currentPassword, String newPassword) {
    return http.post(
      Uri.parse('$baseUrl/api/user/update-password'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'userId': userId,
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      }),
    );
  }
}
