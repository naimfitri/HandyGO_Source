import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart'; // Add this import for MediaType
import 'dart:io'; // For File operations
import 'package:firebase_storage/firebase_storage.dart'; // Add this import

// Update the baseUrl to ensure it's correctly pointing to your backend

class ApiService {
  // Fix 1: Make sure the base URL is correct
  // For Android emulator:
  final String baseUrl = 'https://handygo-api.onrender.com/api/handyman'; 
  // For physical device testing on same network as your backend:
  // final String baseUrl = 'http://YOUR_COMPUTER_IP:3000/api'; 
  
  // Fix 2: Add a debug method to test API connectivity
  Future<bool> testApiConnection() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/health'));
      debugPrint('⚠️ API health check: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('⚠️ API connection test failed: $e');
      return false;
    }
  }

  // Method for handyman registration
  Future<String?> registerHandyman(Map<String, dynamic> handymanData, String uuid) async {
    try {
      // Send data to your Node.js backend
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'uuid': uuid,
          'handymanData': handymanData,
        }),
      );
      
      if (response.statusCode == 201) {
        return null; // Success
      } else {
        // Parse error from response
        Map<String, dynamic> responseBody = jsonDecode(response.body);
        return responseBody['error'] ?? 'Server error: ${response.statusCode}';
      }
    } catch (e) {
      debugPrint('Error: $e');
      return 'Registration failed: $e';
    }
  }
  
  // Method for handyman login
  Future<Map<String, dynamic>> loginHandyman(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );
      
      final responseBody = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        return {
          'success': true,
          'handymanId': responseBody['handymanId'],
          'handymanData': responseBody['handymanData'],
        };
      } else {
        return {
          'success': false,
          'error': responseBody['error'] ?? 'Login failed'
        };
      }
    } catch (e) {
      debugPrint('Login error: $e');
      return {
        'success': false,
        'error': 'Login failed: $e'
      };
    }
  }

  // Method to get handyman data
  Future<Map<String, dynamic>> getHandymanData(String handymanId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/handymen/${handymanId}'),
        headers: {'Content-Type': 'application/json'},
      );
      
      final responseBody = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        return {
          'success': true,
          'handymanData': responseBody['handymanData'],
        };
      } else {
        return {
          'success': false,
          'error': responseBody['error'] ?? 'Failed to get handyman data'
        };
      }
    } catch (e) {
      debugPrint('Error getting handyman data: $e');
      return {
        'success': false,
        'error': 'Failed to get handyman data: $e'
      };
    }
  }

  // Method to get handyman jobs
  Future<Map<String, dynamic>> getHandymanJobs(String handymanId) async {
    try {
      // Debug: Print request URL
      final url = '$baseUrl/handymen/$handymanId/jobs';
      print('⚠️ Requesting jobs from: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      );
      
      // Debug: Print response status and body
      print('⚠️ Response status: ${response.statusCode}');
      print('⚠️ Response body: ${response.body}');
      
      final responseBody = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        // Success
        final jobs = responseBody['jobs'] ?? [];
        print('⚠️ Parsed ${jobs.length} jobs from response');
        
        return {
          'success': true,
          'jobs': jobs,
        };
      } else {
        // Error
        print('⚠️ API error: ${responseBody['error']}');
        
        return {
          'success': false,
          'error': responseBody['error'] ?? 'Failed to get jobs'
        };
      }
    } catch (e) {
      print('⚠️ Exception in getHandymanJobs: $e');
      return {
        'success': false,
        'error': 'Failed to get jobs: $e'
      };
    }
  }

  // Method to update job status
  Future<Map<String, dynamic>> updateJobStatus(String bookingId, String status) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/jobs/$bookingId/status'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'status': status,
        }),
      );
      
      final responseBody = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        return {
          'success': true,
        };
      } else {
        return {
          'success': false,
          'error': responseBody['error'] ?? 'Failed to update job status'
        };
      }
    } catch (e) {
      debugPrint('Error updating job status: $e');
      return {
        'success': false,
        'error': 'Failed to update job status: $e'
      };
    }
  }

  // Method to get materials for a job
  Future<Map<String, dynamic>> getJobInvoice(String bookingId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/bookings/$bookingId/invoice'),
        headers: {'Content-Type': 'application/json'},
      );
      
      debugPrint('⚠️ Get invoice API response: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        return {
          'success': true,
          'items': responseBody['items'] ?? [],
          'serviceCharge': responseBody['serviceCharge'] ?? 0.0,
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to get invoice: ${response.statusCode}',
        };
      }
    } catch (e) {
      debugPrint('⚠️ Error getting invoice: $e');
      return {
        'success': false,
        'error': 'Error: $e',
      };
    }
  }

  // Method to add a material to a job
  Future<Map<String, dynamic>> addJobInvoiceItem(String bookingId, Map<String, dynamic> item) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/bookings/$bookingId/invoice/items'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(item),
      );
      
      debugPrint('⚠️ Add invoice item API response: ${response.statusCode}');
      
      if (response.statusCode == 201) {
        final responseBody = jsonDecode(response.body);
        return {
          'success': true,
          'item': responseBody['item'],
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to add invoice item: ${response.statusCode}',
        };
      }
    } catch (e) {
      debugPrint('⚠️ Error adding invoice item: $e');
      return {
        'success': false,
        'error': 'Error: $e',
      };
    }
  }

  // Method to delete a material from a job
  Future<Map<String, dynamic>> deleteJobInvoiceItem(String bookingId, String itemId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/bookings/$bookingId/invoice/items/$itemId'),
        headers: {'Content-Type': 'application/json'},
      );
      
      debugPrint('⚠️ Delete invoice item API response: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        return {
          'success': true,
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to delete invoice item: ${response.statusCode}',
        };
      }
    } catch (e) {
      debugPrint('⚠️ Error deleting invoice item: $e');
      return {
        'success': false,
        'error': 'Error: $e',
      };
    }
  }

  // Update the getHandymanJobStats method in ApiService
  Future<Map<String, dynamic>> getHandymanJobStats(String handymanId) async {
    try {
      if (handymanId.isEmpty) {
        debugPrint('⚠️ Empty handyman ID provided');
        return {
          'success': false,
          'error': 'Invalid handyman ID',
          'activeBookings': 0,
          'completedJobs': 0,
          'remainingPayout': 0.0,
          'totalRevenue': 0.0,
        };
      }
      
      final response = await http.get(
        Uri.parse('$baseUrl/handymen/$handymanId/stats'),
        headers: {'Content-Type': 'application/json'},
      );
      
      debugPrint('⚠️ Job stats API response: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        try {
          final responseBody = jsonDecode(response.body);
          return {
            'success': true,
            'activeBookings': responseBody['activeBookings'] ?? 0,
            'completedJobs': responseBody['completedJobs'] ?? 0,
            'remainingPayout': responseBody['remainingPayout'] ?? 0.0,
            'totalRevenue': responseBody['totalRevenue'] ?? 0.0,
          };
        } catch (parseError) {
          debugPrint('⚠️ Error parsing API response: $parseError');
          return {
            'success': false,
            'error': 'Failed to parse API response',
            'activeBookings': 0,
            'completedJobs': 0,
            'remainingPayout': 0.0,
            'totalRevenue': 0.0,
          };
        }
      } else {
        return {
          'success': false,
          'error': 'Failed to get job stats: ${response.statusCode}',
          'activeBookings': 0,
          'completedJobs': 0,
          'remainingPayout': 0.0,
          'totalRevenue': 0.0,
        };
      }
    } catch (e) {
      debugPrint('⚠️ Error getting job stats: $e');
      return {
        'success': false,
        'error': 'Error: $e',
        'activeBookings': 0,
        'completedJobs': 0,
        'remainingPayout': 0.0,
        'totalRevenue': 0.0,
      };
    }
  }

  // Add these methods to your ApiService class
  Future<Map<String, dynamic>> getHandymanProfile(String handymanId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/handymen/$handymanId/profile'),
        headers: {'Content-Type': 'application/json'},
      );
      
      debugPrint('⚠️ Profile API response: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        return {
          'success': true,
          'profile': responseBody['profile'] ?? {},
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to get profile: ${response.statusCode}',
        };
      }
    } catch (e) {
      debugPrint('⚠️ Error getting profile: $e');
      return {
        'success': false,
        'error': 'Error: $e',
      };
    }
  }

  // Method to get user data
  Future<Map<String, dynamic>> getUserData(String userId) async {
    try {
      // Construct the URL
      final url = '$baseUrl/user/$userId';
      debugPrint('⚠️ Requesting user data from: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      );
      
      debugPrint('⚠️ Get user data API response: ${response.statusCode}');
      
      // Handle 404 - Not Found error
      if (response.statusCode == 404) {
        debugPrint('⚠️ User not found (404): userId=$userId');
        // Return some default data structure rather than failing
        return {
          'success': true,
          'userData': {
            'name': 'Unknown User', 
            'phone': 'No phone available',
            'email': 'No email available'
          }
        };
      }
      
      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        return {
          'success': true,
          'userData': responseBody['userData'] ?? {},
        };
      } else {
        debugPrint('⚠️ API error response: ${response.body}');
        return {
          'success': false,
          'error': 'Failed to get user data: ${response.statusCode}',
        };
      }
    } catch (e) {
      debugPrint('⚠️ Error getting user data: $e');
      return {
        'success': false,
        'error': 'Error: $e',
      };
    }
  }

  Future<Map<String, dynamic>> updateHandymanProfile(String handymanId, Map<String, dynamic> profileData) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/handymen/$handymanId/profile'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'profile': profileData}),
      );
      
      debugPrint('⚠️ Update profile API response: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        return {
          'success': true,
          'message': responseBody['message'] ?? 'Profile updated successfully',
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to update profile: ${response.statusCode}',
        };
      }
    } catch (e) {
      debugPrint('⚠️ Error updating profile: $e');
      return {
        'success': false,
        'error': 'Error: $e',
      };
    }
  }

  Future<Map<String, dynamic>> updateProfileImage(String handymanId, String imageUrl) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/handymen/$handymanId/profile-image'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'imageUrl': imageUrl}),
      );
      
      debugPrint('⚠️ Update profile image API response: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        return {
          'success': true,
          'message': responseBody['message'] ?? 'Profile image updated successfully',
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to update profile image: ${response.statusCode}',
        };
      }
    } catch (e) {
      debugPrint('⚠️ Error updating profile image: $e');
      return {
        'success': false,
        'error': 'Error: $e',
      };
    }
  }

  Future<Map<String, dynamic>> updateJobServiceCharge(String bookingId, double serviceCharge) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/bookings/$bookingId/invoice/service-charge'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'serviceCharge': serviceCharge}),
      );
      
      debugPrint('⚠️ Update service charge API response: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        return {
          'success': true,
          'message': responseBody['message'] ?? 'Service charge updated successfully',
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to update service charge: ${response.statusCode}',
        };
      }
    } catch (e) {
      debugPrint('⚠️ Error updating service charge: $e');
      return {
        'success': false,
        'error': 'Error: $e',
      };
    }
  }

  Future<Map<String, dynamic>> updateJobTotalFare(String bookingId, double totalFare) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/bookings/$bookingId/fare'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'totalFare': totalFare,
        }),
      );
      
      debugPrint('⚠️ Update fare API response: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        return {
          'success': true,
          'message': responseBody['message'] ?? 'Total fare updated successfully',
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to update total fare: ${response.statusCode}',
        };
      }
    } catch (e) {
      debugPrint('⚠️ Error updating total fare: $e');
      return {
        'success': false,
        'error': 'Error: $e',
      };
    }
  }

  Future<Map<String, dynamic>> deleteJobMaterial(String bookingId, String itemId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/bookings/$bookingId/materials/$itemId'),
        headers: {'Content-Type': 'application/json'},
      );
      
      debugPrint('⚠️ Delete material API response: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        return {
          'success': true,
          'message': responseBody['message'] ?? 'Material deleted successfully',
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to delete material: ${response.statusCode}',
        };
      }
    } catch (e) {
      debugPrint('⚠️ Error deleting material: $e');
      return {
        'success': false,
        'error': 'Error: $e',
      };
    }
  }

  // Method to get job materials/invoice items
  Future<Map<String, dynamic>> getJobMaterials(String bookingId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/bookings/$bookingId/materials'),
        headers: {'Content-Type': 'application/json'},
      );
      
      debugPrint('⚠️ Get materials API response: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        return {
          'success': true,
          'materials': responseBody['materials'] ?? [],
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to get materials: ${response.statusCode}',
        };
      }
    } catch (e) {
      debugPrint('⚠️ Error getting materials: $e');
      return {
        'success': false,
        'error': 'Error: $e',
      };
    }
  }

  // Method to add job material/invoice item
  Future<Map<String, dynamic>> addJobMaterial(String bookingId, String name, int quantity, double price) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/bookings/$bookingId/materials'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'quantity': quantity,
          'price': price,
        }),
      );
      
      debugPrint('⚠️ Add material API response: ${response.statusCode}');
      
      if (response.statusCode == 201) {
        final responseBody = jsonDecode(response.body);
        return {
          'success': true,
          'material': responseBody['material'],
          'message': responseBody['message'] ?? 'Material added successfully',
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to add material: ${response.statusCode}',
        };
      }
    } catch (e) {
      debugPrint('⚠️ Error adding material: $e');
      return {
        'success': false,
        'error': 'Error: $e',
      };
    }
  }

  // Methods for invoice management

  // Get invoice for a booking
  Future<Map<String, dynamic>> getInvoice(String bookingId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/invoices/$bookingId'),
        headers: {'Content-Type': 'application/json'},
      );
      
      debugPrint('⚠️ Get invoice API response: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        return {
          'success': true,
          'invoice': responseBody['invoice'],
        };
      } else if (response.statusCode == 404) {
        return {
          'success': true,
          'invoice': null, // Invoice not found
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to get invoice: ${response.statusCode}',
        };
      }
    } catch (e) {
      debugPrint('⚠️ Error getting invoice: $e');
      return {
        'success': false,
        'error': 'Error: $e',
      };
    }
  }

  // Update the addInvoiceItem method to include the respectManualFare parameter
  Future<Map<String, dynamic>> addInvoiceItem(
      String bookingId, String itemName, int quantity, double pricePerUnit, [bool respectManualFare = false]) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/invoices/$bookingId/items'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'itemName': itemName,
          'quantity': quantity,
          'pricePerUnit': pricePerUnit,
          'respectManualFare': respectManualFare, // Pass this flag to the backend
        }),
      );
      
      if (response.statusCode == 201) {
        final responseBody = jsonDecode(response.body);
        return {
          'success': true,
          'itemId': responseBody['itemId'],
          'totalFare': responseBody['totalFare'],
          'message': responseBody['message'] ?? 'Item added successfully',
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to add item: ${response.statusCode}',
        };
      }
    } catch (e) {
      debugPrint('Error adding invoice item: $e');
      return {
        'success': false,
        'error': 'Error: $e',
      };
    }
  }

  // Update invoice item
  Future<Map<String, dynamic>> updateInvoiceItem(
      String bookingId, String itemId, String? itemName, int? quantity, double? pricePerUnit) async {
    try {
      final Map<String, dynamic> updateData = {};
      if (itemName != null) updateData['itemName'] = itemName;
      if (quantity != null) updateData['quantity'] = quantity;
      if (pricePerUnit != null) updateData['pricePerUnit'] = pricePerUnit;
      
      final response = await http.put(
        Uri.parse('$baseUrl/bookings/$bookingId/invoice/items/$itemId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(updateData),
      );
      
      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        return {
          'success': true,
          'totalFare': responseBody['totalFare'],
          'message': responseBody['message'] ?? 'Item updated successfully',
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to update item: ${response.statusCode}',
        };
      }
    } catch (e) {
      debugPrint('Error updating invoice item: $e');
      return {
        'success': false,
        'error': 'Error: $e',
      };
    }
  }

  // Update the deleteInvoiceItem method to include the respectManualFare parameter
  Future<Map<String, dynamic>> deleteInvoiceItem(
      String bookingId, String itemId, [bool respectManualFare = false]) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/invoices/$bookingId/items/$itemId'),
        headers: {
          'Content-Type': 'application/json',
          'X-Respect-Manual-Fare': respectManualFare.toString(), // Pass this as header
        },
      );
      
      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        return {
          'success': true,
          'totalFare': responseBody['totalFare'],
          'message': responseBody['message'] ?? 'Item deleted successfully',
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to delete item: ${response.statusCode}',
        };
      }
    } catch (e) {
      debugPrint('Error deleting invoice item: $e');
      return {
        'success': false,
        'error': 'Error: $e',
      };
    }
  }

  // Set invoice fare
  Future<Map<String, dynamic>> updateInvoiceFare(
      String bookingId, double fare, bool isManual) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/invoices/$bookingId/fare'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'fare': fare,
          'isManual': isManual, // This flag indicates the fare was manually set
        }),
      );
      
      debugPrint('⚠️ Update invoice fare API response: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        return {
          'success': true,
          'message': responseBody['message'] ?? 'Invoice fare updated successfully',
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to update fare: ${response.statusCode}',
        };
      }
    } catch (e) {
      debugPrint('⚠️ Error updating invoice fare: $e');
      return {
        'success': false,
        'error': 'Error: $e',
      };
    }
  }

  // Add this new method to your ApiService class
  Future<Map<String, dynamic>> updateHandymanLocation(String handymanId, double latitude, double longitude) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/handymen/$handymanId/location'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'latitude': latitude,
          'longitude': longitude,
          'timestamp': DateTime.now().toUtc().toIso8601String(),
        }),
      );

      debugPrint('⚠️ Location update API response: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': 'Location updated successfully',
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to update location: ${response.statusCode}',
        };
      }
    } catch (e) {
      debugPrint('⚠️ Error updating location: $e');
      return {
        'success': false,
        'error': 'Error: $e',
      };
    }
  }

  // Add these methods to your existing ApiService class

  // Get handyman wallet balance and transactions
  Future<Map<String, dynamic>> getHandymanWallet(String handymanId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/handymen/$handymanId/wallet'),
        headers: {'Content-Type': 'application/json'},
      );

      // Check if response is JSON or HTML
      if (response.body.trim().startsWith('<!DOCTYPE html>')) {
        print('Received HTML response instead of JSON: ${response.body.substring(0, 100)}...');
        return {
          'success': false,
          'error': 'Server returned HTML instead of JSON. Server might be down or misconfigured.'
        };
      }

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        return responseData;
      } else {
        print('Server returned error: ${response.statusCode}');
        print('Response body: ${response.body}');
        return {
          'success': false,
          'error': responseData['error'] ?? 'Failed to fetch wallet data (Status: ${response.statusCode})'
        };
      }
    } catch (e) {
      print('Exception in getHandymanWallet: $e');
      if (e is FormatException) {
        return {
          'success': false,
          'error': 'Invalid response format from server. Try again later.'
        };
      }
      return {'success': false, 'error': e.toString()};
    }
  }

  // Get handyman bank details
  Future<Map<String, dynamic>> getHandymanBankDetails(String handymanId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/handymen/$handymanId/bank'),
        headers: {'Content-Type': 'application/json'},
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        return responseData;
      } else {
        return {
          'success': false,
          'error': responseData['error'] ?? 'Failed to fetch bank details'
        };
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // Request a withdrawal
  Future<Map<String, dynamic>> requestWithdrawal(String handymanId, double amount) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/handymen/$handymanId/withdraw'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'amount': amount,
        }),
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        return responseData;
      } else {
        return {
          'success': false,
          'error': responseData['error'] ?? 'Failed to process withdrawal'
        };
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Uploads a profile image for a handyman through the backend API
  /// Returns a map with 'success' flag and 'imageUrl' if successful
  Future<Map<String, dynamic>> uploadProfileImage(String handymanId, File imageFile) async {
    try {
      // Determine the correct MIME type based on file extension
      final String extension = imageFile.path.split('.').last.toLowerCase();
      final String mimeType = _getMimeType(extension);
      
      debugPrint('⚠️ Uploading image with MIME type: $mimeType');
      
      // Create a multipart request to send the file
      var request = http.MultipartRequest(
        'POST', 
        Uri.parse('$baseUrl/handymen/$handymanId/upload-image')
      );
      
      // Add the file to the request
      final fileStream = http.ByteStream(imageFile.openRead());
      final fileLength = await imageFile.length();
      
      final multipartFile = http.MultipartFile(
        'image', 
        fileStream, 
        fileLength,
        filename: '${handymanId}.jpg',
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
        // If the backend API fails, fall back to direct Firebase upload
        debugPrint('⚠️ API upload failed: ${response.statusCode}. Falling back to direct upload...');
        
        // Create a unique filename using the handyman ID
        final fileName = '$handymanId.jpg';
        
        // Upload to Firebase Storage directly
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('profile_handyman')
            .child(fileName);
        
        // Upload the file
        final uploadTask = storageRef.putFile(imageFile);
        
        // Wait for the upload to complete and get the URL
        final snapshot = await uploadTask;
        final downloadUrl = await snapshot.ref.getDownloadURL();
        
        // Call the method to update the profile with the new image URL
        final updateResult = await updateProfileImage(handymanId, downloadUrl);
        
        if (updateResult['success']) {
          return {
            'success': true,
            'imageUrl': downloadUrl,
          };
        } else {
          return {
            'success': false,
            'error': 'Failed to update profile with new image URL',
          };
        }
      }
    } catch (e) {
      debugPrint('❌ Error in uploadProfileImage: $e');
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
  
  /// Fetches a profile image for a handyman from Firebase Storage via the backend API
  /// Returns a map with 'success' flag and 'imageUrl' if successful
  Future<Map<String, dynamic>> fetchProfileImage(String handymanId) async {
    try {
      debugPrint('⚠️ Fetching profile image for handyman: $handymanId');
      
      // First try the backend endpoint that handles Firebase Storage
      final response = await http.get(
        Uri.parse('$baseUrl/images/$handymanId'),
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
      
      debugPrint('⚠️ Could not fetch image from backend API, falling back to direct fetch');
      
      // Fallback: Try to get the profile directly 
      final profileResponse = await getHandymanProfile(handymanId);
      
      if (profileResponse['success'] == true && 
          profileResponse['profile'] != null &&
          profileResponse['profile']['profileImage'] != null) {
        final imageUrl = profileResponse['profile']['profileImage'];
        debugPrint('✅ Successfully got profile image URL from profile data');
        
        return {
          'success': true,
          'imageUrl': imageUrl,
          'fromProfile': true,
        };
      }
      
      // If all else fails, try direct Firebase Storage
      try {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('profile_handyman')
            .child('$handymanId.jpg');
        
        final downloadUrl = await storageRef.getDownloadURL();
        
        debugPrint('✅ Successfully got image directly from Firebase Storage');
        
        return {
          'success': true,
          'imageUrl': downloadUrl,
          'fromFirebase': true,
        };
      } catch (storageError) {
        debugPrint('❌ Firebase Storage direct access error: $storageError');
      }
      
      return {
        'success': false,
        'error': 'Image not found after all attempts',
      };
      
    } catch (e) {
      debugPrint('❌ Error fetching profile image: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
  
  // Add this new method to fetch handyman ratings
  Future<Map<String, dynamic>> getHandymanRatings(String handymanId) async {
    try {
      // First try the API endpoint
      final response = await http.get(
        Uri.parse('$baseUrl/handymen/$handymanId/ratings'),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        return {
          'success': true,
          'ratings': responseBody['ratings'] ?? [],
          'averageRating': responseBody['averageRating'] ?? 0.0,
        };
      }
      
      // Fallback to direct Firebase access if API fails
      debugPrint('⚠️ API failed, trying direct Firebase access for ratings');
    
      
      return {
        'success': false,
        'error': 'No ratings found for this handyman',
        'ratings': [],
        'averageRating': 0.0,
      };
    } catch (e) {
      debugPrint('⚠️ Error getting handyman ratings: $e');
      return {
        'success': false,
        'error': 'Failed to get ratings: $e',
        'ratings': [],
        'averageRating': 0.0,
      };
    }
  }

  // Add method to process refund when a booking is rejected
  Future<Map<String, dynamic>> refundBookingFee(String bookingId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/handymen/refund-booking-fee'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'bookingId': bookingId,
        }),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': responseData['message'] ?? 'Refund processed successfully',
          'refundAmount': responseData['refundAmount'],
          'userId': responseData['userId'],
        };
      } else {
        debugPrint('Error refunding booking fee: ${responseData['error']}');
        return {
          'success': false,
          'error': responseData['error'] ?? 'Failed to process refund',
        };
      }
    } catch (e) {
      debugPrint('Exception refunding booking fee: $e');
      return {
        'success': false,
        'error': 'An unexpected error occurred',
      };
    }
  }
}
