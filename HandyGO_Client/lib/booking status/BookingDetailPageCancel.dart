import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import '../api_service.dart';

// Define consistent style constants
class AppTheme {
  // Primary colors
  static const Color primary = Color(0xFF3F51B5);       // Royal Blue
  static const Color secondary = Color(0xFF9C27B0);     // Vibrant Violet
  static const Color background = Color(0xFFFAFAFF);    // Ghost White
  
  // Text colors
  static const Color textHeading = Color(0xFF2E2E2E);   // Dark Slate Gray
  static const Color textBody = Color(0xFF6E6E6E);      // Slate Grey
  
  // Status colors
  static const Color success = Color(0xFF4CAF50);       // Spring Green
  static const Color warning = Color(0xFFFF7043);       // Coral
  
  // Icon backgrounds
  static const Color iconBgBlue = Color(0xFFE3F2FD);    // Blue tint
  static const Color iconBgPurple = Color(0xFFF3E5F5);  // Purple tint
  
  // Navigation
  static const Color navInactive = Color(0xFF9E9E9E);   // Grey
}

class BookingDetailPageCancel extends StatefulWidget {
  final String bookingId;
  final String userId;

  const BookingDetailPageCancel({
    Key? key,
    required this.bookingId,
    required this.userId,
  }) : super(key: key);

  @override
  _BookingDetailPageCancelState createState() =>
      _BookingDetailPageCancelState();
}

class _BookingDetailPageCancelState extends State<BookingDetailPageCancel> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  Map<String, dynamic> _bookingDetails = {};
  Map<String, dynamic> _handymanDetails = {};
  String? _errorMessage;
  
  // Animation controller for page elements
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    );
    
    _fadeAnimation = CurvedAnimation(
      parent: _animationController, 
      curve: Curves.easeInOut,
    );
    
    _fetchBookingDetails();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _fetchBookingDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final bookingResponse = await _apiService.getBookingDetails(widget.bookingId);

      if (bookingResponse.statusCode == 200) {
        final bookingData = json.decode(bookingResponse.body);

        if (bookingData['assigned_to'] != null) {
          try {
            final handymanResponse = await _apiService.getHandyman(bookingData['assigned_to']);
            if (handymanResponse.statusCode == 200) {
              setState(() {
                _handymanDetails = json.decode(handymanResponse.body);
              });
            }
          } catch (e) {
            print('Error fetching handyman details: $e');
          }
        }

        setState(() {
          _bookingDetails = bookingData;
          _isLoading = false;
        });
        
        // Start animation after data is loaded
        _animationController.forward();
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

  Widget _buildInfoRow(String label, String value, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.iconBgBlue,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 16,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(width: 10),
          ],
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: AppTheme.textBody,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppTheme.textHeading,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, {IconData? icon}) {
    return Row(
      children: [
        if (icon != null) ...[
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.iconBgBlue,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppTheme.primary, size: 18),
          ),
          SizedBox(width: 12),
        ],
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.textHeading,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        title: Text('Cancelled Booking', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _errorMessage != null
              ? _buildErrorState()
              : _buildContentWithAnimation(),
    );
  }
  
  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 60,
            color: AppTheme.warning.withOpacity(0.7),
          ),
          SizedBox(height: 16),
          Text(
            _errorMessage!,
            style: TextStyle(color: AppTheme.warning),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _fetchBookingDetails,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: Icon(Icons.refresh),
            label: Text('Retry'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildContentWithAnimation() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Banner
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              decoration: BoxDecoration(
                color: AppTheme.warning.withOpacity(0.1),
                border: Border.all(color: AppTheme.warning.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.warning.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.cancel_outlined, color: AppTheme.warning),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CANCELLED',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.warning,
                            letterSpacing: 1.2,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'This booking has been cancelled',
                          style: TextStyle(
                            color: AppTheme.warning,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24),

            // Service Details
            _buildServiceDetailsCard(),
            SizedBox(height: 16),

            // Cancellation Reason (if available)
            if (_bookingDetails.containsKey('cancellation_reason') && 
                _bookingDetails['cancellation_reason'] != null &&
                _bookingDetails['cancellation_reason'].toString().isNotEmpty)
              _buildCancellationReasonCard(),
            SizedBox(height: 16),

            // Location Card
            _buildLocationCard(),
            SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
  
  Widget _buildServiceDetailsCard() {
    final hasDescription = _bookingDetails['description'] != null && 
                           _bookingDetails['description'].toString().isNotEmpty;
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Service Details', icon: Icons.build_outlined),
            SizedBox(height: 16),
            
            // Enhanced service type display
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.secondary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _bookingDetails['category'] ?? 'Unknown',
                style: TextStyle(
                  color: AppTheme.secondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            SizedBox(height: 16),
            
            _buildInfoRow('Booking ID', _bookingDetails['booking_id'] ?? 'Unknown', 
                icon: Icons.confirmation_number_outlined),
            Divider(height: 1, thickness: 0.5, color: Colors.grey.withOpacity(0.2)),
            
            _buildInfoRow(
              'Date',
              _bookingDetails['starttimestamp'] != null
                ? _formatDate(_bookingDetails['starttimestamp'])
                : 'Unknown',
              icon: Icons.calendar_today_outlined
            ),
            Divider(height: 1, thickness: 0.5, color: Colors.grey.withOpacity(0.2)),
            
            _buildInfoRow(
              'Time',
              _bookingDetails['starttimestamp'] != null && _bookingDetails['endtimestamp'] != null
                ? '${_formatTime(_bookingDetails['starttimestamp'])} - ${_formatTime(_bookingDetails['endtimestamp'])}'
                : 'Unknown',
              icon: Icons.access_time_outlined
            ),
            
            // Add notes section inside service details card
            if (hasDescription) ...[
              Divider(height: 24, thickness: 0.5, color: Colors.grey.withOpacity(0.2)),
              
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.iconBgPurple,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.description_outlined, color: AppTheme.secondary, size: 16),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Description',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textBody,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.withOpacity(0.2)),
                ),
                child: Text(
                  _bookingDetails['description'],
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textBody,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildCancellationReasonCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Cancellation Reason', icon: Icons.info_outline),
            SizedBox(height: 16),
            
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.warning.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.warning.withOpacity(0.2)),
              ),
              child: Text(
                _bookingDetails['cancellation_reason'] ?? 'No reason provided',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textBody,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildLocationCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Location', icon: Icons.location_on_outlined),
            SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.iconBgPurple,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.home_outlined, color: AppTheme.secondary, size: 18),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _bookingDetails['address'] ?? 'No address provided',
                        style: TextStyle(
                          color: AppTheme.textHeading,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              ],
            ),
          ],
        ),
      ),
    );
  }
}