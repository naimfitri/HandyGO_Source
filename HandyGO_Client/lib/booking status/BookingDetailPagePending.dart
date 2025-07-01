import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async'; // Add this import for TimeoutException
import 'package:intl/intl.dart';
import '../api_service.dart'; // Import the API service

class BookingDetailPagePending extends StatefulWidget {
  final String bookingId;
  final String userId;

  const BookingDetailPagePending({
    Key? key,
    required this.bookingId,
    required this.userId,
  }) : super(key: key);

  @override
  _BookingDetailPagePendingState createState() => _BookingDetailPagePendingState();
}

class _BookingDetailPagePendingState extends State<BookingDetailPagePending> {
  final ApiService _apiService = ApiService(); // Create ApiService instance
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
        
        // Fetch handyman details if assigned using ApiService
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
  
  // Add helper method to handle expertise field that could be string or list
  String _formatExpertise(dynamic expertise) {
    if (expertise == null) return 'General';
    
    if (expertise is List) {
      return expertise.join(', '); // Join list items with a comma
    } else {
      return expertise.toString(); // Handle string or other types
    }
  }

  Future<void> _cancelBooking() async {
    // Show confirmation dialog
    final bool? shouldCancel = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cancel Booking'),
        content: Text(
          'Are you sure you want to cancel this booking? The processing fee will be refunded to your wallet.',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Yes, Cancel'),
            style: TextButton.styleFrom(
              foregroundColor: Color(0xFFFF7043), // Use warning color
            ),
          ),
        ],
      ),
    );
    
    // If user didn't confirm, exit the function
    if (shouldCancel != true) return;
    
    // Track if loading dialog is showing
    bool isLoadingDialogShowing = true;
    
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(color: Color(0xFF3F51B5)),
            SizedBox(width: 20),
            Text('Cancelling booking...'),
          ],
        ),
      ),
    );
    
    try {
      // Add timeout to prevent API call from hanging indefinitely
      final response = await _apiService.cancelBooking(widget.bookingId, widget.userId)
          .timeout(Duration(seconds: 15), onTimeout: () {
        throw TimeoutException("The request took too long to complete. Please try again.");
      });
      
      // Make sure to dismiss loading dialog
      if (isLoadingDialogShowing && Navigator.canPop(context)) {
        Navigator.pop(context);
        isLoadingDialogShowing = false;
      }

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        
        // Display success with refund information
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Booking Cancelled'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your booking has been cancelled successfully.'),
                SizedBox(height: 16),
                Text(
                  'A refund of RM ${result['refund_amount'].toStringAsFixed(2)} has been credited to your wallet.',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'New wallet balance: RM ${result['new_wallet_balance'].toStringAsFixed(2)}',
                  style: TextStyle(color: Color(0xFF4CAF50)),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context); // Return to bookings list
                },
                child: Text('OK', style: TextStyle(color: Color(0xFF3F51B5))),
              ),
            ],
          ),
        );
      } else {
        final errorMsg = response.statusCode == 400 || response.statusCode == 403 
          ? json.decode(response.body)['message'] 
          : 'Failed to cancel booking';
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg)),
        );
      }
    } catch (e) {
      // Always ensure loading dialog is dismissed
      if (isLoadingDialogShowing && Navigator.canPop(context)) {
        Navigator.pop(context);
        isLoadingDialogShowing = false;
      }
      
      // Show specific error message
      String errorMsg = 'Error: $e';
      if (e is TimeoutException) {
        errorMsg = 'Request timed out. Please check your connection and try again.';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Define theme colors based on new theme
    final Color primaryColor = Color(0xFF3F51B5); // Royal Blue
    final Color secondaryColor = Color(0xFF9C27B0); // Vibrant Violet
    final Color backgroundColor = Color(0xFFFAFAFF); // Ghost White
    final Color headingColor = Color(0xFF2E2E2E); // Dark Slate Gray
    final Color bodyTextColor = Color(0xFF6E6E6E); // Slate Grey
    final Color warningColor = Color(0xFFFF7043); // Coral for pending status
    final Color successColor = Color(0xFF4CAF50); // Spring Green
    final Color cardBackgroundColor = Colors.white;
    final Color iconBackgroundColor = Color(0xFFE3F2FD); // Light blue tint for icon backgrounds

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text('Booking Details', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
        backgroundColor: primaryColor,
        elevation: 1,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _errorMessage!,
                        style: TextStyle(color: warningColor),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchBookingDetails,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 1,
                          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text('Retry'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status Banner
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                        decoration: BoxDecoration(
                          color: warningColor.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: warningColor, width: 1),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: warningColor.withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.pending_outlined,
                                color: warningColor,
                                size: 18,
                              ),
                            ),
                            SizedBox(width: 12),
                            Column(
                              children: [
                                Text(
                                  'PENDING',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: warningColor,
                                    letterSpacing: 0.5,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Waiting for handyman to accept your booking',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: warningColor.withOpacity(0.9),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 24),
                      
                      // Service Details Card
                      Card(
                        elevation: 1,
                        color: cardBackgroundColor,
                        margin: EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: iconBackgroundColor,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.home_repair_service_outlined, color: primaryColor),
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    'Service Details',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: headingColor,
                                    ),
                                  ),
                                ],
                              ),
                              Divider(color: Colors.grey.withOpacity(0.2), thickness: 1, height: 24),
                              _buildInfoRow('Service Type', _bookingDetails['category'] ?? 'Not specified'),
                              _buildInfoRow('Booking ID', _bookingDetails['booking_id'] ?? 'Unknown'),
                              _buildInfoRow('Date', _bookingDetails['starttimestamp'] != null 
                                  ? _formatDate(_bookingDetails['starttimestamp'])
                                  : 'Unknown'
                              ),
                              _buildInfoRow('Time', 
                                _bookingDetails['starttimestamp'] != null && _bookingDetails['endtimestamp'] != null 
                                  ? '${_formatTime(_bookingDetails['starttimestamp'])} - ${_formatTime(_bookingDetails['endtimestamp'])}'
                                  : 'Unknown'
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      // Location Card
                      Card(
                        elevation: 1,
                        color: cardBackgroundColor,
                        margin: EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: iconBackgroundColor,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.location_on_outlined, color: primaryColor),
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    'Location',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: headingColor,
                                    ),
                                  ),
                                ],
                              ),
                              Divider(color: Colors.grey.withOpacity(0.2), thickness: 1, height: 24),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      _bookingDetails['address'] ?? 'Address not provided',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: bodyTextColor,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      // Notes Card
                      if (_bookingDetails['description'] != null && _bookingDetails['description'].toString().isNotEmpty)
                        Card(
                          elevation: 1,
                          color: cardBackgroundColor,
                          margin: EdgeInsets.only(bottom: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: iconBackgroundColor,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(Icons.description_outlined, color: primaryColor),
                                    ),
                                    SizedBox(width: 12),
                                    Text(
                                      'Notes',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: headingColor,
                                      ),
                                    ),
                                  ],
                                ),
                                Divider(color: Colors.grey.withOpacity(0.2), thickness: 1, height: 24),
                                Text(
                                  _bookingDetails['description'],
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: bodyTextColor,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      SizedBox(height: 12),
                      
                      // Cancel Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _cancelBooking,
                          icon: Icon(Icons.cancel_outlined),
                          label: Text('Cancel Booking', style: TextStyle(fontSize: 16)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: warningColor,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 15),
                            elevation: 1,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Cancellation will refund the processing fee to your wallet.',
                        style: TextStyle(
                          fontSize: 12,
                          color: bodyTextColor,
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    final Color labelColor = Color(0xFF6E6E6E); // Slate Grey
    final Color valueColor = Color(0xFF2E2E2E); // Dark Slate Gray
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w400,
                color: labelColor,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}