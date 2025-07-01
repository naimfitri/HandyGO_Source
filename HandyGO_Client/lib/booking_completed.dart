import 'package:flutter/material.dart';
import 'dart:convert';
import 'api_service.dart';  // Import the API service

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

class BookingCompletedPage extends StatefulWidget {
  final String userId;

  const BookingCompletedPage({required this.userId, Key? key}) : super(key: key);

  @override
  _BookingCompletedPageState createState() => _BookingCompletedPageState();
}

class _BookingCompletedPageState extends State<BookingCompletedPage> {
  final ApiService _apiService = ApiService(); // Create instance of API service
  bool _isLoading = true;
  List<Map<String, dynamic>> _completedBookings = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchCompletedBookings();
  }

  Future<void> _fetchCompletedBookings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _apiService.getCompletedBookings(widget.userId);

      if (response.statusCode == 200) {
        // Print the raw response for debugging
        print('Response body: ${response.body}');
        
        final List<dynamic> bookingsData = json.decode(response.body);
        
        setState(() {
          _completedBookings = bookingsData
              .map<Map<String, dynamic>>((booking) => booking as Map<String, dynamic>)
              .toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load bookings: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
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
        title: const Text(
          'Completed Bookings',
          style: TextStyle(
            fontSize: 18, 
            fontWeight: FontWeight.w600, 
            color: AppColors.textHeading
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.textHeading),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: AppColors.primary),
            onPressed: _fetchCompletedBookings,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
        ),
      );
    }
    
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 56, color: AppColors.error),
            SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: TextStyle(
                fontSize: 18, 
                fontWeight: FontWeight.w600, 
                color: AppColors.textHeading
              ),
            ),
            SizedBox(height: 8),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _errorMessage!,
                style: TextStyle(color: AppColors.textBody),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: _fetchCompletedBookings,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              child: Text(
                'Try Again',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      );
    }
    
    if (_completedBookings.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _fetchCompletedBookings,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _completedBookings.length,
        itemBuilder: (context, index) {
          final booking = _completedBookings[index];
          return _buildBookingCard(
            booking: booking, // Pass the whole booking object
            serviceName: booking['category'] ?? 'Unknown Service',
            date: booking['date'] ?? 'Unknown Date',
            time: booking['time'] ?? 'Unknown Time',
            address: booking['address'] ?? 'Unknown Location',
            description: booking['description'] ?? 'No description provided',
            status: booking['status'] ?? 'Completed-Paid',
            totalFare: booking['total_fare']?.toString() ?? 'N/A',
          );
        },
      ),
    );
  }

  // Empty State UI with updated colors
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline, 
            size: 80, 
            color: AppColors.textBody.withOpacity(0.5)
          ),
          SizedBox(height: 20),
          Text(
            'No Completed Bookings',
            style: TextStyle(
              fontSize: 18, 
              fontWeight: FontWeight.w600,
              color: AppColors.textHeading
            ),
          ),
          SizedBox(height: 12),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'You don\'t have any completed bookings yet.',
              style: TextStyle(color: AppColors.textBody),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: 32),
          OutlinedButton(
            onPressed: _fetchCompletedBookings,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: BorderSide(color: AppColors.primary),
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'Refresh',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  // Booking Card UI with updated theme colors
  Widget _buildBookingCard({
    required Map<String, dynamic> booking, // Add booking parameter
    required String serviceName,
    required String date,
    required String time,
    required String address,
    required String description,
    required String status,
    required String totalFare,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.success.withOpacity(0.2),
                  child: Icon(Icons.check_circle, color: AppColors.success, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        serviceName,
                        style: TextStyle(
                          fontSize: 17, 
                          fontWeight: FontWeight.w600,
                          color: AppColors.textHeading
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Address: $address',
                        style: TextStyle(fontSize: 14, color: AppColors.textBody),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Text(
                  "Status", 
                  style: TextStyle(
                    fontWeight: FontWeight.w500, 
                    color: AppColors.textHeading
                  )
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.success.withOpacity(0.3),
                      width: 1
                    ),
                  ),
                  child: Text(
                    "Completed",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: AppColors.success,
                    ),
                  ),
                ),
              ],
            ),
            Divider(color: AppColors.background, height: 24),
            Row(
              children: [
                Icon(Icons.calendar_today, color: AppColors.primary, size: 18),
                const SizedBox(width: 10),
                Text(
                  "$time, $date",
                  style: TextStyle(
                    fontSize: 15, 
                    fontWeight: FontWeight.w500,
                    color: AppColors.textHeading
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.monetization_on, color: AppColors.primary, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "RM $totalFare",
                        style: TextStyle(
                          fontSize: 17, 
                          fontWeight: FontWeight.bold,
                          color: AppColors.secondary,
                        ),
                      ),
                      if (booking.containsKey('fare') && booking.containsKey('items_total'))
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            "Service: RM ${booking['fare']} + Materials: RM ${booking['items_total']}",
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textBody,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.description, color: AppColors.primary, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: AppColors.textBody,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
