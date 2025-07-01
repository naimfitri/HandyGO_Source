import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
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
  static const Color cardBackground = Color(0xFFFFFFFF); // Pure White for cards

  // Text Colors
  static const Color textHeading = Color(0xFF333333); // Charcoal Grey
  static const Color textBody = Color(0xFF666666); // Medium Grey

  // Status Colors
  static const Color success = Color(0xFF66BB6A); // Green
  static const Color warning = Color(0xFFFFA726); // Orange
  static const Color error = Color(0xFFEF5350); // Red
}

class BookingPage extends StatefulWidget {
  final String category;
  final String userName;
  final String userEmail;
  final String userId;
  final String handymanId;
  final String handymanName;
  final String selectedDate;
  final String selectedTimeSlot;

  const BookingPage({
    Key? key,
    required this.category,
    required this.userName,
    required this.userEmail,
    required this.userId,
    required this.handymanId,
    required this.handymanName,
    required this.selectedDate,
    required this.selectedTimeSlot,
  }) : super(key: key);

  @override
  _BookingPageState createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  final ApiService _apiService = ApiService();  // Create ApiService instance
  final TextEditingController _descriptionController = TextEditingController();
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  Map<String, dynamic> _userData = {};
  Map<String, dynamic> _handymanData = {};
  String? _formattedDate;
  double _processingFee = 0.0; // Will be loaded from Firebase
  double walletBalance = 0.0; // Will be loaded from user data
  bool _termsAccepted = false; // Add terms acceptance state

  @override
  void initState() {
    super.initState();
    _loadUserAndHandymanData();

    // Format the date for display
    try {
      final dateComponents = widget.selectedDate.split('-');
      if (dateComponents.length == 3) {
        final date = DateTime(
          int.parse(dateComponents[0]),
          int.parse(dateComponents[1]),
          int.parse(dateComponents[2]),
        );
        _formattedDate = DateFormat('EEEE, MMMM d, yyyy').format(date);
      } else {
        _formattedDate = widget.selectedDate;
      }
    } catch (e) {
      _formattedDate = widget.selectedDate;
    }
  }

  Future<void> _loadUserAndHandymanData() async {
    try {
      // Load user data (including primaryAddress)
      final userResponse = await _apiService.getUserData(widget.userId);

      // Load handyman data
      final handymanResponse = await _apiService.getHandyman(widget.handymanId);

      // Load processing fee
      final feeResponse = await _apiService.getGlobalSettings();

      if (userResponse.statusCode == 200 && handymanResponse.statusCode == 200) {
        final userData = json.decode(userResponse.body);
        final handymanData = json.decode(handymanResponse.body);

        // Set wallet balance from user data
        double userWalletBalance = 0.0;
        if (userData['wallet'] != null) {
          userWalletBalance = (userData['wallet'] is int)
              ? userData['wallet'].toDouble()
              : userData['wallet']?.toDouble() ?? 0.0;
        }

        // Set processing fee from response
        double fee = 15.0; // Default
        if (feeResponse.statusCode == 200) {
          final feeData = json.decode(feeResponse.body);
          fee = feeData['amount']?.toDouble() ?? 15.0;
        }

        setState(() {
          _userData = userData;
          _handymanData = handymanData;
          walletBalance = userWalletBalance;
          _processingFee = fee;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load data';
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

  Future<void> _submitBooking() async {
    if (walletBalance < _processingFee) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Insufficient wallet balance. Please top up first.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!_termsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please accept the terms and conditions to proceed.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please provide a job description.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      // Format address from user data
      final address = _formatAddress(_userData['primaryAddress']);

      // Get coordinates if available
      double? latitude;
      double? longitude;
      if (_userData['primaryAddress'] != null) {
        if (_userData['primaryAddress']['latitude'] != null) {
          latitude = double.tryParse(_userData['primaryAddress']['latitude'].toString());
        }
        if (_userData['primaryAddress']['longitude'] != null) {
          longitude = double.tryParse(_userData['primaryAddress']['longitude'].toString());
        }
      }

      // Calculate proper timestamps for start and end time
      final timestamps = _calculateTimestamps(widget.selectedDate, widget.selectedTimeSlot);
      
      // Generate a booking ID using UUID
      final bookingId = Uuid().v4();

      // Prepare booking data with all required fields
      final bookingData = {
        'user_id': widget.userId,
        'userId': widget.userId, // Include both formats to be safe
        'handymanId': widget.handymanId,
        'assigned_to': widget.handymanId,
        'booking_id': bookingId,
        'category': widget.category,
        'date': widget.selectedDate,
        'timeSlot': widget.selectedTimeSlot,
        'assigned_slot': widget.selectedTimeSlot,
        'notes': _descriptionController.text,
        'description': _descriptionController.text,
        'processingFee': _processingFee,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'starttimestamp': timestamps['start'],
        'endtimestamp': timestamps['end'],
        'status': 'Pending',
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'hasMaterials': false,
        'termsAccepted': true
      };

      print('Sending booking data: ${json.encode(bookingData)}');

      // Create booking and deduct processing fee using ApiService
      final response = await _apiService.createBookingWithFee(bookingData);

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 201) {
        final bookingResult = json.decode(response.body);

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => BookingConfirmationPage(
              bookingId: bookingResult['booking_id'],
              bookingData: bookingData,
              userName: widget.userName,
              handymanName: widget.handymanName,
              formattedDate: _formattedDate ?? widget.selectedDate,
              slotTimeRange: _getTimeRangeForSlot(widget.selectedTimeSlot),
              processingFee: _processingFee,
            ),
          ),
        );
      } else {
        setState(() {
          _isSubmitting = false;
          _errorMessage = 'Failed to create booking: ${response.statusCode}';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create booking: ${response.body}'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isSubmitting = false;
        _errorMessage = 'Error: $e';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating booking: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _getTimeFrameFromSlot(String? slot) {
    if (slot == null) return '';
    
    switch (slot) {
      case '1':
        return '8:00 AM - 12:00 PM';
      case '2':
        return '1:00 PM - 5:00 PM';
      case '3':
        return '6:00 PM - 10:00 PM';
      default:
        return slot; // Return the original value if not a recognized slot
    }
  }

  String _getTimeRangeForSlot(String slotName) {
    // Extract slot number if format is "Slot X"
    if (slotName.startsWith('Slot ')) {
      final slotNumber = slotName.substring(5);
      return _getTimeFrameFromSlot(slotNumber);
    }
    
    // Handle direct slot numbers
    return _getTimeFrameFromSlot(slotName);
  }

  Map<String, String> _calculateTimestamps(String dateStr, String slotName) {
    // Parse the dateStr to a DateTime
    final dateComponents = dateStr.split('-');
    final date = DateTime(
      int.parse(dateComponents[0]),
      int.parse(dateComponents[1]),
      int.parse(dateComponents[2]),
    );

    // Get the time frame based on the slot
    String timeFrame = _getTimeRangeForSlot(slotName);
    
    // Default values
    int startHour = 8;
    int endHour = 12;
    
    // Set hours based on the slot - ensure they match the time frames returned by _getTimeFrameFromSlot
    if (timeFrame.contains('8:00 AM - 12:00 PM') || slotName == '1' || slotName == 'Slot 1') {
      startHour = 8;  // 8:00 AM
      endHour = 12;   // 12:00 PM
    } else if (timeFrame.contains('1:00 PM - 5:00 PM') || slotName == '2' || slotName == 'Slot 2') {
      startHour = 13; // 1:00 PM
      endHour = 17;   // 5:00 PM
    } else if (timeFrame.contains('6:00 PM - 10:00 PM') || slotName == '3' || slotName == 'Slot 3') {
      startHour = 18; // 6:00 PM
      endHour = 22;   // 10:00 PM
    }

    // Create start and end DateTime objects
    final startTime = DateTime(date.year, date.month, date.day, startHour);
    final endTime = DateTime(date.year, date.month, date.day, endHour);

    // Format to exact ISO strings with milliseconds
    return {
      'start': '${startTime.toIso8601String().split('.')[0]}.000Z', // Ensure format: 2025-05-26T10:00:00.000Z
      'end': '${endTime.toIso8601String().split('.')[0]}.000Z', // Ensure format: 2025-05-26T10:00:00.000Z
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Booking Confirmation',
          style: TextStyle(
            color: AppColors.textHeading,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: AppColors.textHeading),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: AppColors.error,
                        size: 48,
                      ),
                      SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: TextStyle(color: AppColors.error),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadUserAndHandymanData,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text('Retry'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Receipt-style booking details card
                        Card(
                          elevation: 2,
                          shadowColor: Colors.black.withOpacity(0.1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          color: AppColors.surface,
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Center(
                                  child: Text(
                                    'Booking Details',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textHeading,
                                    ),
                                  ),
                                ),
                                Divider(
                                  thickness: 1,
                                  color: AppColors.primaryLight.withOpacity(0.2),
                                ),
                                SizedBox(height: 16),
                                _buildInfoRow(
                                  'Service Type',
                                  widget.category,
                                  icon: Icons.home_repair_service,
                                ),
                                SizedBox(height: 12),
                                _buildInfoRow(
                                  'Date',
                                  _formattedDate ?? widget.selectedDate,
                                  icon: Icons.calendar_today,
                                ),
                                SizedBox(height: 12),
                                _buildInfoRow(
                                  'Time',
                                  _getTimeRangeForSlot(widget.selectedTimeSlot),
                                  icon: Icons.access_time,
                                ),
                                SizedBox(height: 12),
                                _buildInfoRow(
                                  'Handyman',
                                  widget.handymanName,
                                  icon: Icons.person,
                                ),
                                SizedBox(height: 12),
                                _buildInfoRow(
                                  'Customer',
                                  widget.userName,
                                  icon: Icons.account_circle,
                                ),
                                SizedBox(height: 12),
                                _buildInfoRow(
                                  'Address',
                                  _formatAddress(_userData['primaryAddress']) ?? 'No address provided',
                                  icon: Icons.location_on,
                                ),
                                SizedBox(height: 12),
                                _isLoading || _processingFee == 0.0
                                    ? CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                                      )
                                    : _buildInfoRow(
                                        'Processing Fee',
                                        'RM ${_processingFee.toStringAsFixed(2)}',
                                        highlight: true,
                                        icon: Icons.monetization_on,
                                      ),
                                SizedBox(height: 16),
                                // Wallet balance indicator
                                Container(
                                  padding: EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.amber.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: AppColors.amber.withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.account_balance_wallet,
                                        color: AppColors.amber,
                                        size: 20,
                                      ),
                                      SizedBox(width: 8),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Wallet Balance',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w500,
                                              color: AppColors.textHeading,
                                              fontSize: 14,
                                            ),
                                          ),
                                          SizedBox(height: 2),
                                          Text(
                                            'RM ${walletBalance.toStringAsFixed(2)}',
                                            style: TextStyle(
                                              color: walletBalance < _processingFee
                                                  ? AppColors.error
                                                  : AppColors.success,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Spacer(),
                                      if (walletBalance < _processingFee)
                                        Text(
                                          'Insufficient balance',
                                          style: TextStyle(
                                            color: AppColors.error,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: 24),
                        // Description input
                        Text(
                          'Job Description',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textHeading,
                          ),
                        ),
                        SizedBox(height: 8),
                        TextFormField(
                          controller: _descriptionController,
                          decoration: InputDecoration(
                            hintText: 'Describe the job (required)',
                            hintStyle: TextStyle(color: AppColors.textBody.withOpacity(0.6)),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: AppColors.textBody.withOpacity(0.3)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: AppColors.textBody.withOpacity(0.3)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: AppColors.primary, width: 2),
                            ),
                            filled: true,
                            fillColor: AppColors.surface,
                            contentPadding: EdgeInsets.all(16),
                          ),
                          maxLines: 4,
                          style: TextStyle(color: AppColors.textHeading),
                        ),
                        SizedBox(height: 32),
                        // Add terms and conditions acceptance
                        SizedBox(height: 24),
                        CheckboxListTile(
                          title: Text(
                            "By proceeding, I agree to pay the final service cost determined after job completion.",
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textBody,
                            ),
                          ),
                          value: _termsAccepted,
                          onChanged: (bool? value) {
                            setState(() {
                              _termsAccepted = value ?? false;
                            });
                          },
                          controlAffinity: ListTileControlAffinity.leading,
                          activeColor: AppColors.primary,
                          checkColor: Colors.white,
                          contentPadding: EdgeInsets.zero,
                        ),
                        
                        SizedBox(height: 16),
                        
                        // Submit button
                        ElevatedButton(
                          onPressed: (walletBalance < _processingFee || _isSubmitting || !_termsAccepted) 
                              ? null 
                              : _submitBooking,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: AppColors.textBody.withOpacity(0.3),
                            disabledForegroundColor: Colors.white70,
                            minimumSize: Size(double.infinity, 54),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: _isSubmitting
                              ? SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  'Confirm Booking',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                        if (walletBalance < _processingFee)
                          Padding(
                            padding: const EdgeInsets.only(top: 12.0),
                            child: Text(
                              'Please top up your wallet before booking',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.error,
                                fontSize: 14,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool highlight = false, IconData? icon}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Icon(
            icon,
            size: 18,
            color: AppColors.primary,
          ),
          SizedBox(width: 8),
        ],
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: AppColors.textBody,
            ),
          ),
        ),
        Text(
          ': ',
          style: TextStyle(
            color: AppColors.textBody,
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            value,
            style: TextStyle(
              color: highlight ? AppColors.primary : AppColors.textHeading,
              fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }

  String? _formatAddress(Map<String, dynamic>? primaryAddress) {
    if (primaryAddress == null) return 'No address provided';

    final List<String> addressParts = [];

    if (primaryAddress['unitName'] != null && primaryAddress['unitName'].toString().isNotEmpty) {
      addressParts.add(primaryAddress['unitName'].toString());
    }

    if (primaryAddress['buildingName'] != null && primaryAddress['buildingName'].toString().isNotEmpty) {
      addressParts.add(primaryAddress['buildingName'].toString());
    }

    if (primaryAddress['streetName'] != null && primaryAddress['streetName'].toString().isNotEmpty) {
      addressParts.add(primaryAddress['streetName'].toString());
    }

    if (primaryAddress['city'] != null && primaryAddress['city'].toString().isNotEmpty) {
      addressParts.add(primaryAddress['city'].toString());
    }

    if (primaryAddress['postalCode'] != null && primaryAddress['postalCode'].toString().isNotEmpty) {
      addressParts.add(primaryAddress['postalCode'].toString());
    }

    if (primaryAddress['country'] != null && primaryAddress['country'].toString().isNotEmpty) {
      addressParts.add(primaryAddress['country'].toString());
    }

    return addressParts.join(', ');
  }
}

// Replace the standalone function with one that uses the ApiService
Future<Map<String, dynamic>> fetchHandymanDetails(String handymanId) async {
  final apiService = ApiService();
  return apiService.fetchHandymanDetails(handymanId);
}

// Booking confirmation page shown after successful booking
class BookingConfirmationPage extends StatelessWidget {
  final String bookingId;
  final Map<String, dynamic> bookingData;
  final String userName;
  final String handymanName;
  final String formattedDate;
  final String slotTimeRange;
  final double processingFee;

  const BookingConfirmationPage({
    Key? key,
    required this.bookingId,
    required this.bookingData,
    required this.userName,
    required this.handymanName,
    required this.formattedDate,
    required this.slotTimeRange,
    required this.processingFee,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Booking Confirmed',
          style: TextStyle(
            color: AppColors.textHeading,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        backgroundColor: AppColors.success.withOpacity(0.1),
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: Icon(Icons.close, color: AppColors.textHeading),
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: 20),
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.success.withOpacity(0.1),
                ),
                child: Icon(
                  Icons.check_circle_outline,
                  color: AppColors.success,
                  size: 60,
                ),
              ),
              SizedBox(height: 24),
              const Text(
                'Booking Confirmed!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textHeading,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Your booking has been successfully created',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textBody,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 32),
              Card(
                elevation: 2,
                shadowColor: Colors.black.withOpacity(0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: AppColors.success.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                color: AppColors.surface,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Text(
                          'Booking Receipt',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textHeading,
                          ),
                        ),
                      ),
                      Divider(
                        thickness: 1,
                        color: AppColors.success.withOpacity(0.2),
                      ),
                      SizedBox(height: 20),
                      _buildInfoRow('Booking ID', bookingId),
                      Divider(color: AppColors.background),
                      _buildInfoRow('Service Type', bookingData['category']),
                      Divider(color: AppColors.background),
                      _buildInfoRow('Date', formattedDate),
                      Divider(color: AppColors.background),
                      _buildInfoRow('Time', slotTimeRange),
                      Divider(color: AppColors.background),
                      // Show the processing fee that was deducted
                      _buildInfoRow(
                        'Processing Fee',
                        'RM ${processingFee.toStringAsFixed(2)}',
                        highlight: true,
                      ),
                      Divider(color: AppColors.background),
                      _buildInfoRow('Handyman', handymanName),
                      if (bookingData['notes'] != null && bookingData['notes'].isNotEmpty) ...[
                        Divider(color: AppColors.background),
                        _buildInfoRow('Notes', bookingData['notes']),
                      ],
                      SizedBox(height: 20),
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: AppColors.success,
                              size: 20,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'A notification will be sent to the handyman. You will be updated on the status of your booking.',
                                    style: TextStyle(
                                      color: AppColors.textBody,
                                      fontSize: 13,
                                      height: 1.4,
                                    ),
                                  ),
                                  SizedBox(height: 6),
                                  Text(
                                    'If booking still not accepted or rejected, booking will be automatically expired after 2 hours.',
                                    style: TextStyle(
                                      color: AppColors.warning,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  // Navigate back to home or service selection page
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: Size(220, 54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Back to Home',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.textBody,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: highlight ? FontWeight.bold : FontWeight.w500,
                color: highlight ? AppColors.primary : AppColors.textHeading,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
