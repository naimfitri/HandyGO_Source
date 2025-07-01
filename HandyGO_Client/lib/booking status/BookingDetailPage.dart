import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import '../api_service.dart'; // Import ApiService

class BookingDetailPage extends StatefulWidget {
  final String bookingId;
  final String userId;

  const BookingDetailPage({
    Key? key,
    required this.bookingId,
    required this.userId,
  }) : super(key: key);

  @override
  _BookingDetailPageState createState() => _BookingDetailPageState();
}

class _BookingDetailPageState extends State<BookingDetailPage> {
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

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.green;
      case 'in progress':
        return Colors.blue;
      case 'completed':
        return Colors.green.shade700;
      case 'cancelled':
        return Colors.red;
      case 'expired':
        return Colors.brown.shade700;  // Dark brown color for expired bookings
      default:
        return Colors.grey;
    }
  }

  Future<void> _cancelBooking() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cancel Booking'),
        content: const Text(
          'Are you sure you want to cancel this booking? The processing fee will be refunded to your wallet.',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('No'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              
              // Show loading dialog
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const AlertDialog(
                  content: Row(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(width: 20),
                      Text('Cancelling booking...'),
                    ],
                  ),
                ),
              );
              
              try {
                final response = await _apiService.cancelBooking(widget.bookingId, widget.userId);

                // Close loading dialog
                Navigator.pop(context);

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
                            style: TextStyle(color: Colors.green),
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _fetchBookingDetails(); // Refresh data
                          },
                          child: Text('OK'),
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
                // Close loading dialog if open
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                }
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            child: Text('Yes, Cancel'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F6FC),
      appBar: AppBar(
        title: Text(
          'Booking Details',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _fetchBookingDetails,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchBookingDetails,
                        child: Text('Retry'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Status Card
                        Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Status',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 12, 
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(
                                          _bookingDetails['status'] ?? 'Unknown'
                                        ).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: _getStatusColor(
                                            _bookingDetails['status'] ?? 'Unknown'
                                          ),
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        _bookingDetails['status'] ?? 'Unknown',
                                        style: TextStyle(
                                          color: _getStatusColor(
                                            _bookingDetails['status'] ?? 'Unknown'
                                          ),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                
                                // Show cancel button only for pending bookings
                                if ((_bookingDetails['status'] ?? '').toLowerCase() == 'pending')
                                  Padding(
                                    padding: const EdgeInsets.only(top: 12.0),
                                    child: OutlinedButton(
                                      onPressed: _cancelBooking,
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.red,
                                        side: BorderSide(color: Colors.red),
                                      ),
                                      child: Text('Cancel Booking'),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        
                        SizedBox(height: 16),
                        
                        // Service Details Card
                        Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Service Details',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 16),
                                _buildInfoRow('Service Type', _bookingDetails['category'] ?? 'Not specified'),
                                SizedBox(height: 8),
                                _buildInfoRow('Booking ID', _bookingDetails['booking_id'] ?? 'Unknown'),
                                SizedBox(height: 8),
                                _buildInfoRow('Date', _bookingDetails['starttimestamp'] != null 
                                    ? _formatDate(_bookingDetails['starttimestamp'])
                                    : 'Unknown'
                                ),
                                SizedBox(height: 8),
                                _buildInfoRow('Time', 
                                  _bookingDetails['starttimestamp'] != null && _bookingDetails['endtimestamp'] != null 
                                    ? '${_formatTime(_bookingDetails['starttimestamp'])} - ${_formatTime(_bookingDetails['endtimestamp'])}'
                                    : 'Unknown'
                                ),
                                SizedBox(height: 8),
                                // Add this line to show the processing fee
                                _buildInfoRow('Processing Fee', 
                                  _bookingDetails['processing_fee'] != null 
                                    ? 'RM ${_bookingDetails['processing_fee'].toString()}'
                                    : 'RM 15.00'
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        SizedBox(height: 16),
                        
                        // Handyman Card
                        Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Handyman',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 16),
                                _buildInfoRow('Name', _handymanDetails['name'] ?? 'Not assigned yet'),
                                SizedBox(height: 8),
                                _buildInfoRow('Expertise', _handymanDetails['expertise'] ?? 'Not specified'),
                                SizedBox(height: 8),
                                _buildInfoRow('Rating', _handymanDetails['rating'] != null 
                                    ? '${_handymanDetails['rating']} / 5.0'
                                    : 'No ratings yet'
                                ),
                                SizedBox(height: 8),
                                _buildInfoRow('Location', _handymanDetails['location'] ?? 'Not specified'),
                              ],
                            ),
                          ),
                        ),
                        
                        SizedBox(height: 16),
                        
                        // Location Card
                        Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Service Location',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 16),
                                _buildInfoRow('Address', _bookingDetails['address'] ?? 'Not specified'),
                              ],
                            ),
                          ),
                        ),
                        
                        SizedBox(height: 16),
                        
                        // Description Card
                        Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Job Description',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 16),
                                Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    _bookingDetails['description'] ?? 'No description provided',
                                    style: TextStyle(
                                      height: 1.5,
                                    ),
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
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
        ),
        Text(': '),
        Expanded(
          flex: 3,
          child: Text(
            value,
            style: TextStyle(
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
}