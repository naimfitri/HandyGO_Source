import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import '../api_service.dart'; // Import ApiService

// Define theme colors for consistent usage
class AppTheme {
  static const Color primary = Color(0xFF3F51B5); // Royal Blue
  static const Color secondary = Color(0xFF9C27B0); // Vibrant Violet
  static const Color background = Color(0xFFFAFAFF); // Ghost White
  static const Color textHeading = Color(0xFF2E2E2E); // Dark Slate Gray
  static const Color textBody = Color(0xFF6E6E6E); // Slate Grey
  static const Color success = Color(0xFF4CAF50); // Spring Green
  static const Color warning = Color(0xFFFF7043); // Coral
  static const Color blueTint = Color(0xFFE3F2FD); // Light Blue Tint
  static const Color purpleTint = Color(0xFFF3E5F5); // Light Purple Tint
}

class BookingDetailPageExpired extends StatefulWidget {
  final String bookingId;
  final String userId;

  const BookingDetailPageExpired({
    Key? key,
    required this.bookingId,
    required this.userId,
  }) : super(key: key);

  @override
  _BookingDetailPageExpiredState createState() => _BookingDetailPageExpiredState();
}

class _BookingDetailPageExpiredState extends State<BookingDetailPageExpired> {
  final ApiService _apiService = ApiService(); // Create instance of API service
  bool _isLoading = true;
  Map<String, dynamic> _bookingDetails = {};
  Map<String, dynamic> _handymanDetails = {};
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchBookingDetails();
  }

  Future<void> _fetchBookingDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Fetch booking details using ApiService
      final bookingResponse = await _apiService.getBookingDetails(widget.bookingId);

      if (bookingResponse.statusCode == 200) {
        final bookingData = json.decode(bookingResponse.body);
        setState(() {
          _bookingDetails = Map<String, dynamic>.from(bookingData);
        });

        // Fetch handyman details if we have handyman ID using ApiService
        if (_bookingDetails['assigned_to'] != null) {
          final handymanResponse = await _apiService.getHandyman(_bookingDetails['assigned_to']);

          if (handymanResponse.statusCode == 200) {
            setState(() {
              _handymanDetails = json.decode(handymanResponse.body);
            });
          }
        }

        setState(() {
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load booking details: ${bookingResponse.statusCode}';
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

  String _formatDate(String timestamp) {
    try {
      final DateTime date = DateTime.parse(timestamp);
      return DateFormat('EEEE, MMMM d, yyyy').format(date);
    } catch (e) {
      return 'Unknown date';
    }
  }

  String _formatTime(String timestamp) {
    try {
      final DateTime date = DateTime.parse(timestamp);
      return DateFormat('h:mm a').format(date);
    } catch (e) {
      return 'Unknown time';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(
          'Expired Booking',
          style: TextStyle(
            fontWeight: FontWeight.bold, 
            color: Colors.white
          ),
        ),
        backgroundColor: AppTheme.primary,
        elevation: 2,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetchBookingDetails,
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: AppTheme.primary,
                strokeWidth: 3,
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    margin: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: AppTheme.warning,
                          size: 56,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Something went wrong',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textHeading,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.textBody),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _fetchBookingDetails,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            elevation: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Status Card with expired info
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Status header with color
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                decoration: BoxDecoration(
                                  color: AppTheme.blueTint,
                                  border: Border(
                                    bottom: BorderSide(
                                      color: Colors.brown.shade300,
                                      width: 1,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.access_time_filled,
                                          color: Colors.brown.shade700,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Status',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.textHeading,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12, 
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.brown.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: Colors.brown.shade700,
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        'Expired',
                                        style: TextStyle(
                                          color: Colors.brown.shade700,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              
                              // Status content
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.brown.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.brown.shade200,
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.info_outline, 
                                        color: Colors.brown.shade700,
                                        size: 24,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'This booking has expired',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.brown.shade700,
                                                fontSize: 16,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              'This booking was not accepted within the time limit and has expired. Any processing fee has been automatically refunded to your wallet.',
                                              style: TextStyle(
                                                height: 1.5,
                                                color: AppTheme.textBody,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Service Details Card
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: AppTheme.blueTint,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.home_repair_service_outlined,
                                        color: AppTheme.primary,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Service Details',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.textHeading,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                _buildInfoRow(
                                  'Service Type',
                                  _bookingDetails['category'] ?? 'Not specified',
                                  Icons.category_outlined
                                ),
                                const Divider(height: 24),
                                _buildInfoRow(
                                  'Booking ID',
                                  _bookingDetails['booking_id'] ?? 'Unknown',
                                  Icons.confirmation_number_outlined
                                ),
                                const Divider(height: 24),
                                _buildInfoRow(
                                  'Date',
                                  _bookingDetails['starttimestamp'] != null 
                                      ? _formatDate(_bookingDetails['starttimestamp'])
                                      : 'Unknown',
                                  Icons.calendar_today_outlined
                                ),
                                const Divider(height: 24),
                                _buildInfoRow(
                                  'Time', 
                                  _bookingDetails['starttimestamp'] != null && _bookingDetails['endtimestamp'] != null 
                                      ? '${_formatTime(_bookingDetails['starttimestamp'])} - ${_formatTime(_bookingDetails['endtimestamp'])}'
                                      : 'Unknown',
                                  Icons.access_time_outlined
                                ),
                                
                                const Divider(height: 24),
                                _buildInfoRow(
                                  'Expired Date', 
                                  _bookingDetails['expiry_timestamp'] != null 
                                    ? _formatDate(_bookingDetails['expiry_timestamp'])
                                    : DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now().subtract(const Duration(days: 1))),
                                  Icons.event_busy_outlined,
                                  valueColor: Colors.brown.shade700
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Location Card
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: AppTheme.purpleTint,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.location_on_outlined,
                                        color: AppTheme.secondary,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Service Location',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.textHeading,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Icon(Icons.home_outlined, color: AppTheme.textBody, size: 22),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          _bookingDetails['address'] ?? 'Not specified',
                                          style: TextStyle(
                                            color: AppTheme.textHeading,
                                            height: 1.5,
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
                        
                        const SizedBox(height: 20),
                        
                        // Description Card
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: AppTheme.blueTint,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.description_outlined,
                                        color: AppTheme.primary,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Job Description',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.textHeading,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: Text(
                                    _bookingDetails['description'] ?? 'No description provided',
                                    style: TextStyle(
                                      height: 1.5,
                                      color: AppTheme.textHeading,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon, {Color? valueColor}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 18,
            color: AppTheme.textBody,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textBody,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  color: valueColor ?? AppTheme.textHeading,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
