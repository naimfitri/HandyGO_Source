import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import '../api_service.dart'; // Add this import

class BookingDetailPagePaid extends StatefulWidget {
  final String bookingId;
  final String userId;

  const BookingDetailPagePaid({
    Key? key,
    required this.bookingId,
    required this.userId,
  }) : super(key: key);

  @override
  _BookingDetailPagePaidState createState() => _BookingDetailPagePaidState();
}

class _BookingDetailPagePaidState extends State<BookingDetailPagePaid> {
  final ApiService _apiService = ApiService(); // Create ApiService instance
  bool _isLoading = true;
  Map<String, dynamic> _bookingDetails = {};
  Map<String, dynamic> _invoiceDetails = {};
  Map<String, dynamic> _handymanDetails = {};
  Map<String, dynamic> _paymentDetails = {};
  String? _errorMessage;

  double _userRating = 0.0;
  bool _isSubmittingRating = false;
  bool _hasRated = false;
  String _userReview = '';
  final TextEditingController _reviewController = TextEditingController();
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  bool _isEditing = false;
  double _originalRating = 0.0;
  String _originalReview = '';

  @override
  void initState() {
    super.initState();
    _fetchBookingDetails().then((_) {
      _checkExistingRating();
    });
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
        
        // Fetch invoice details using ApiService
        try {
          final invoiceResponse = await _apiService.getInvoiceDetails(widget.bookingId);
          
          if (invoiceResponse.statusCode == 200) {
            final invoiceData = json.decode(invoiceResponse.body);
            setState(() {
              _invoiceDetails = invoiceData;
            });
          }
        } catch (e) {
          print('Error fetching invoice details: $e');
        }
        
        // Fetch handyman details using ApiService
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
        
        // Fetch payment details using ApiService
        try {
          final paymentResponse = await _apiService.getPaymentDetails(widget.bookingId);
          
          if (paymentResponse.statusCode == 200) {
            setState(() {
              _paymentDetails = json.decode(paymentResponse.body);
            });
          }
        } catch (e) {
          print('Error fetching payment details: $e');
        }
        
        setState(() {
          _bookingDetails = bookingData;
          _isLoading = false;
        });
        
        print('Booking details fetched successfully: ${_bookingDetails['assigned_to']}');
        return;
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

  Future<void> _checkExistingRating() async {
    print('Checking for existing rating...');
    try {
      final handymanId = _bookingDetails['assigned_to'];
      if (handymanId == null) {
        print('No handyman ID available in booking details');
        return;
      }
      
      print('Found handyman ID: $handymanId for booking: ${widget.bookingId}');
      
      // Try to get rating from API first (faster) using ApiService
      try {
        final response = await _apiService.getRating(handymanId, widget.bookingId)
            .timeout(Duration(seconds: 5));
        
        print('API Response status: ${response.statusCode}');
        print('API Response body: ${response.body}');
        
        if (response.statusCode == 200) {
          final ratingData = json.decode(response.body);
          
          print('Rating found: $ratingData');
          
          setState(() {
            _hasRated = true;
            _userRating = (ratingData['rating'] as num).toDouble();
            _userReview = ratingData['review'] as String? ?? '';
            _reviewController.text = _userReview;
            
            // Store original values for cancel functionality
            _originalRating = _userRating;
            _originalReview = _userReview;
          });
          return; // Exit early if API request succeeded
        }
      } catch (apiError) {
        print('API error, falling back to Firebase: $apiError');
        // Fall back to Firebase directly
      }
      
      // Fallback: Check Firebase directly
      print('Checking Firebase for rating...');
      final ratingSnapshot = await _database
        .child('ratings')
        .child(handymanId)
        .child(widget.bookingId)
        .get();
      
      print('Firebase snapshot exists: ${ratingSnapshot.exists}');
      
      if (ratingSnapshot.exists) {
        final ratingData = ratingSnapshot.value as Map<dynamic, dynamic>;
        print('Rating data from Firebase: $ratingData');
        
        setState(() {
          _hasRated = true;
          _userRating = (ratingData['rating'] as num).toDouble();
          _userReview = ratingData['review'] as String? ?? '';
          _reviewController.text = _userReview;
          
          // Store original values for cancel functionality
          _originalRating = _userRating;
          _originalReview = _userReview;
        });
      } else {
        print('No existing rating found for this booking');
      }
    } catch (e) {
      print('Error checking existing rating: $e');
    }
  }

  Future<void> _submitRating() async {
    if (_userRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a rating before submitting')),
      );
      return;
    }
    
    final handymanId = _bookingDetails['assigned_to'];
    if (handymanId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cannot find handyman information')),
      );
      return;
    }

    setState(() {
      _isSubmittingRating = true;
    });

    try {
      // First, get handyman's current rating data
      final handymanSnapshot = await _database
          .child('handymen')
          .child(handymanId)
          .get();
      
      if (!handymanSnapshot.exists) {
        throw Exception('Handyman data not found');
      }
      
      final handymanData = handymanSnapshot.value as Map<dynamic, dynamic>;
      
      // Calculate new average rating
      double currentAverage = 0.0;
      int totalRatings = 0;
      
      if (handymanData.containsKey('average_rating')) {
        currentAverage = handymanData['average_rating'] is double
            ? handymanData['average_rating']
            : double.parse(handymanData['average_rating'].toString());
      }
      
      if (handymanData.containsKey('total_ratings')) {
        totalRatings = handymanData['total_ratings'] is int
            ? handymanData['total_ratings']
            : int.parse(handymanData['total_ratings'].toString());
      }
      
      // Check if this is an update to an existing rating
      final ratingSnapshot = await _database
          .child('ratings')
          .child(handymanId)
          .child(widget.bookingId)
          .get();
      
      double newAverage;
      int newTotalRatings;
      
      if (ratingSnapshot.exists) {
        // Update existing rating
        final existingRating = (ratingSnapshot.value as Map<dynamic, dynamic>)['rating'] as num;
        
        // Remove old rating from average
        double sumWithoutOldRating = currentAverage * totalRatings - existingRating.toDouble();
        
        // Add new rating to sum and recalculate average
        newAverage = (sumWithoutOldRating + _userRating) / totalRatings;
        newTotalRatings = totalRatings; // Total count remains the same
      } else {
        // New rating
        newTotalRatings = totalRatings + 1;
        newAverage = ((currentAverage * totalRatings) + _userRating) / newTotalRatings;
      }
      
      // Save the rating to ratings/handymanId/bookingId
      await _database
          .child('ratings')
          .child(handymanId)
          .child(widget.bookingId)
          .set({
        'userId': widget.userId,
        'rating': _userRating,
        'review': _reviewController.text.trim(),
        'timestamp': ServerValue.timestamp,
        'userName': _bookingDetails['userName'] ?? 'Anonymous',
      });
      
      // Update handyman's average rating
      await _database
          .child('handymen')
          .child(handymanId)
          .update({
        'average_rating': newAverage,
        'total_ratings': newTotalRatings,
      });
      
      // Also update the rating in API using ApiService
      try {
        final response = await _apiService.submitRating(
          handymanId: handymanId, 
          bookingId: widget.bookingId,
          userId: widget.userId,
          rating: _userRating,
          review: _reviewController.text.trim(),
          userName: _bookingDetails['userName'] ?? 'Anonymous',
        );
        
        if (response.statusCode != 200) {
          print('API Error: ${response.body}');
        }
      } catch (e) {
        print('API Error: $e');
      }
      
      setState(() {
        _isSubmittingRating = false;
        _hasRated = true;
        _isEditing = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Thank you for your rating!')),
      );
    } catch (e) {
      setState(() {
        _isSubmittingRating = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error submitting rating: $e')),
      );
      print('Error submitting rating: $e');
    }
  }

  Future<void> _shareReceipt() async {
    // Format invoice details as text
    String receiptText = 'HandyGo Service Receipt\n';
    receiptText += '=======================\n\n';
    receiptText += 'Receipt #: ${widget.bookingId.substring(0, 8)}\n';
    
    if (_invoiceDetails['createdAt'] != null) {
      receiptText += 'Date: ${_formatDate(_invoiceDetails['createdAt'])}\n';
    }
    
    receiptText += 'Service: ${_bookingDetails['category'] ?? 'Not specified'}\n';
    receiptText += 'Handyman: ${_handymanDetails['name'] ?? 'Unknown'}\n\n';
    
    receiptText += 'Items:\n';
    if (_invoiceDetails['items'] != null && _invoiceDetails['items'].isNotEmpty) {
      _invoiceDetails['items'].forEach((key, item) {
        receiptText += '- ${item['itemName']} x${item['quantity']}: RM ${item['total'].toStringAsFixed(2)}\n';
      });
    } else {
      receiptText += '- No items listed\n';
    }
    
    // Calculate totals
    double itemsTotal = 0.0;
    if (_invoiceDetails['items'] != null) {
      _invoiceDetails['items'].forEach((key, item) {
        itemsTotal += item['total']?.toDouble() ?? 0.0;
      });
    }
    
    double serviceFee = _invoiceDetails['fare']?.toDouble() ?? 0.0;
    double totalFare = serviceFee + itemsTotal;
    
    receiptText += '\nMaterials Subtotal: RM ${itemsTotal.toStringAsFixed(2)}\n';
    receiptText += 'Service Fee: RM ${serviceFee.toStringAsFixed(2)}\n';
    receiptText += 'Total Amount: RM ${totalFare.toStringAsFixed(2)}\n\n';
    
    if (_paymentDetails['paymentDate'] != null) {
      receiptText += 'Payment Date: ${_formatDate(_paymentDetails['paymentDate'])}\n';
    }
    
    receiptText += 'Payment Method: Wallet\n\n';
    receiptText += 'Thank you for using HandyGo!';
    
    await Share.share(receiptText, subject: 'HandyGo Service Receipt');
  }

  Future<void> _downloadReceipt() async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Receipt download started'),
      ),
    );
    
    // Implement PDF generation and download logic here if needed
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

  @override
  Widget build(BuildContext context) {
    // Define theme colors
    final Color primaryColor = Color(0xFF3F51B5); // Royal Blue
    final Color secondaryColor = Color(0xFF9C27B0); // Vibrant Violet
    final Color backgroundColor = Color(0xFFFAFAFF); // Ghost White
    final Color headingColor = Color(0xFF2E2E2E); // Dark Slate Gray
    final Color bodyTextColor = Color(0xFF6E6E6E); // Slate Grey
    final Color successColor = Color(0xFF4CAF50); // Spring Green
    final Color warningColor = Color(0xFFFF7043); // Coral for warnings
    final Color cardBackgroundColor = Colors.white;
    final Color iconBackgroundBlue = Color(0xFFE3F2FD); // Blue tint for icon backgrounds
    final Color iconBackgroundPurple = Color(0xFFF3E5F5); // Purple tint for icon backgrounds

    // Calculate total items cost
    double itemsTotal = 0.0;
    if (_invoiceDetails['items'] != null) {
      _invoiceDetails['items'].forEach((key, item) {
        itemsTotal += item['total']?.toDouble() ?? 0.0;
      });
    }
    
    // Calculate total fare
    double totalFare = _invoiceDetails['fare']?.toDouble() ?? 0.0;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text('Receipt', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
        backgroundColor: primaryColor,
        elevation: 1,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.share_outlined, color: Colors.white),
            onPressed: _shareReceipt,
            tooltip: 'Share Receipt',
          ),
          IconButton(
            icon: Icon(Icons.download_outlined, color: Colors.white),
            onPressed: _downloadReceipt,
            tooltip: 'Download Receipt',
          ),
        ],
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
                      // Status Banner - Green for paid
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                        decoration: BoxDecoration(
                          color: successColor.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: successColor, width: 1),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: successColor.withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.check_circle_outline,
                                color: successColor,
                                size: 18,
                              ),
                            ),
                            SizedBox(width: 12),
                            Column(
                              children: [
                                Text(
                                  'PAYMENT COMPLETED',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: successColor,
                                    letterSpacing: 0.5,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Service completed - Payment successful',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: successColor,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 24),
                      
                      // Invoice Card
                      Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: iconBackgroundBlue,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(Icons.receipt_outlined, color: primaryColor),
                                      ),
                                      SizedBox(width: 12),
                                      Text(
                                        'Receipt',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: headingColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: primaryColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '#${widget.bookingId.substring(0, 8)}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: primaryColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 12),
                              Divider(color: Colors.grey.withOpacity(0.2), thickness: 1),
                              SizedBox(height: 12),
                              
                              // Payment details
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Invoice Date',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w400,
                                      color: bodyTextColor,
                                    ),
                                  ),
                                  Text(
                                    _invoiceDetails['createdAt'] != null 
                                        ? _formatDate(_invoiceDetails['createdAt'])
                                        : 'Unknown',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      color: headingColor,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Payment Date',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w400,
                                      color: bodyTextColor,
                                    ),
                                  ),
                                  Text(
                                    _paymentDetails['paymentDate'] != null 
                                        ? _formatDate(_paymentDetails['paymentDate'])
                                        : 'Unknown',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      color: headingColor,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 20),
                              
                              // Service details
                              Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: iconBackgroundBlue,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.home_repair_service_outlined, 
                                      size: 16, 
                                      color: primaryColor
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Service Details',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: headingColor,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 12),
                              _buildInfoRow('Service Type', _bookingDetails['category'] ?? 'Not specified'),
                              _buildInfoRow('Date', _bookingDetails['starttimestamp'] != null 
                                  ? _formatDate(_bookingDetails['starttimestamp'])
                                  : 'Unknown'
                              ),
                              _buildInfoRow('Time', 
                                _bookingDetails['starttimestamp'] != null && _bookingDetails['endtimestamp'] != null 
                                  ? '${_formatTime(_bookingDetails['starttimestamp'])} - ${_formatTime(_bookingDetails['endtimestamp'])}'
                                  : 'Unknown'
                              ),
                              _buildInfoRow('Handyman', _handymanDetails['name'] ?? 'Unknown'),
                              
                              SizedBox(height: 20),
                              Divider(color: Colors.grey.withOpacity(0.2), thickness: 1),
                              SizedBox(height: 12),
                              
                              // Items list
                              Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: iconBackgroundBlue,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.inventory_2_outlined, 
                                      size: 16, 
                                      color: primaryColor
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Items / Materials',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: headingColor,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 16),
                              
                              // Headers
                              Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      'Item',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: headingColor,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 1,
                                    child: Text(
                                      'Qty',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: headingColor,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      'Price',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: headingColor,
                                      ),
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      'Total',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: headingColor,
                                      ),
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              Divider(height: 1, color: Colors.grey.withOpacity(0.2)),
                              
                              // Item rows
                              if (_invoiceDetails['items'] != null && _invoiceDetails['items'].isNotEmpty)
                                ..._invoiceDetails['items'].entries.map((entry) {
                                  final item = entry.value;
                                  return Column(
                                    children: [
                                      SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Expanded(
                                            flex: 3,
                                            child: Text(
                                              item['itemName'] ?? 'Unknown item',
                                              style: TextStyle(color: bodyTextColor),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 1,
                                            child: Text(
                                              '${item['quantity'] ?? 0}',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(color: bodyTextColor),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              'RM ${(item['pricePerUnit'] ?? 0).toStringAsFixed(2)}',
                                              textAlign: TextAlign.right,
                                              style: TextStyle(color: bodyTextColor),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              'RM ${(item['total'] ?? 0).toStringAsFixed(2)}',
                                              textAlign: TextAlign.right,
                                              style: TextStyle(
                                                color: headingColor,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 12),
                                      Divider(height: 1, color: Colors.grey.withOpacity(0.2)),
                                    ],
                                  );
                                }).toList()
                              else
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                                  child: Text(
                                    'No items',
                                    style: TextStyle(
                                      fontStyle: FontStyle.italic,
                                      color: bodyTextColor,
                                    ),
                                  ),
                                ),
                              
                              SizedBox(height: 20),
                              
                              // Summary
                              Container(
                                padding: EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.grey.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Materials Subtotal',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w400,
                                            color: bodyTextColor,
                                          ),
                                        ),
                                        Text(
                                          'RM ${itemsTotal.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w500,
                                            color: headingColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Service Fee',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w400,
                                            color: bodyTextColor,
                                          ),
                                        ),
                                        Text(
                                          'RM ${totalFare.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w500,
                                            color: headingColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 16),
                                    Divider(height: 1, color: Colors.grey.withOpacity(0.3)),
                                    SizedBox(height: 16),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Total Amount',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                            color: headingColor,
                                          ),
                                        ),
                                        Text(
                                          'RM ${(totalFare + itemsTotal).toStringAsFixed(2)}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                            color: primaryColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              
                              SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Payment Status',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: headingColor,
                                    ),
                                  ),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6
                                    ),
                                    decoration: BoxDecoration(
                                      color: successColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: successColor.withOpacity(0.5), width: 1)
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.check_circle_outline,
                                          size: 14,
                                          color: successColor,
                                        ),
                                        SizedBox(width: 6),
                                        Text(
                                          'PAID',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: successColor,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 24),
                      
                      // Rating Card
                      Card(
                        elevation: 1,
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
                                      color: iconBackgroundPurple,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.star_outline, color: secondaryColor),
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    _hasRated && !_isEditing 
                                      ? '${_handymanDetails['name'] ?? 'the handyman'}'
                                      : 'Rate Your Experience',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: headingColor,
                                    ),
                                  ),
                                  Spacer(),
                                  if (_hasRated && !_isEditing)
                                    Row(
                                      children: [
                                        // Edit button
                                        IconButton(
                                          onPressed: () {
                                            setState(() {
                                              _isEditing = true;
                                              _originalRating = _userRating;
                                              _originalReview = _userReview;
                                            });
                                          },
                                          icon: Icon(Icons.edit_outlined, color: primaryColor, size: 18),
                                          tooltip: 'Edit Rating',
                                          constraints: BoxConstraints(minWidth: 36),
                                          padding: EdgeInsets.zero,
                                        ),
                                        SizedBox(width: 4),
                                        Container(
                                          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: successColor.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: successColor.withOpacity(0.5)),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(Icons.check, size: 12, color: successColor),
                                              SizedBox(width: 4),
                                              Text(
                                                'RATED',
                                                style: TextStyle(
                                                  color: successColor,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                              SizedBox(height: 16),
                              
                              // Enhance the display when already rated
                              if (_hasRated && !_isEditing)
                                Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: backgroundColor,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.grey.shade200),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          // Display rating stars in a more interesting way
                                          Container(
                                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                            decoration: BoxDecoration(
                                              color: Colors.amber.shade50,
                                              borderRadius: BorderRadius.circular(30),
                                              border: Border.all(color: Colors.amber.shade200),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  _userRating.toString(),
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 18,
                                                    color: Colors.amber.shade800,
                                                  ),
                                                ),
                                                SizedBox(width: 6),
                                                ...List.generate(5, (index) {
                                                  if (index < _userRating.floor())
                                                    return Icon(Icons.star, color: Colors.amber, size: 18);
                                                  else if (index < _userRating.ceil() && _userRating.ceil() > _userRating.floor())
                                                    return Icon(Icons.star_half, color: Colors.amber, size: 18);
                                                  else
                                                    return Icon(Icons.star_border, color: Colors.amber, size: 18);
                                                }),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      
                                      if (_userReview.isNotEmpty) ...[
                                        SizedBox(height: 16),
                                        Container(
                                          padding: EdgeInsets.all(12),
                                          width: double.infinity,
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: Colors.grey.shade200),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Icon(Icons.format_quote, color: secondaryColor.withOpacity(0.4), size: 16),
                                                  SizedBox(width: 8),
                                                  Text(
                                                    'Your Review',
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.w500,
                                                      color: headingColor,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              SizedBox(height: 8),
                                              Text(
                                                _userReview,
                                                style: TextStyle(
                                                  fontStyle: FontStyle.italic,
                                                  color: bodyTextColor,
                                                  height: 1.4,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                )
                              else
                                Center(
                                  child: RatingBar.builder(
                                    initialRating: _userRating,
                                    minRating: 1,
                                    direction: Axis.horizontal,
                                    allowHalfRating: true,
                                    itemCount: 5,
                                    glow: false,
                                    itemSize: 36,
                                    unratedColor: Colors.amber.withOpacity(0.3),
                                    ignoreGestures: _hasRated && !_isEditing,
                                    itemBuilder: (context, _) => Icon(
                                      Icons.star,
                                      color: Colors.amber,
                                    ),
                                    onRatingUpdate: (rating) {
                                      if (_hasRated && !_isEditing) return;
                                      setState(() {
                                        _userRating = rating;
                                      });
                                    },
                                  ),
                                ),
                                
                              if (!(_hasRated && !_isEditing)) ...[
                                SizedBox(height: 16),
                                
                                // Review text field
                                TextField(
                                  controller: _reviewController,
                                  readOnly: _hasRated && !_isEditing,
                                  maxLines: 3,
                                  decoration: InputDecoration(
                                    hintText: _hasRated && !_isEditing ? 
                                      (_userReview.isEmpty ? 'No written review' : null) : 
                                      'Write your review here (optional)',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(color: Colors.grey.shade300),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(color: primaryColor),
                                    ),
                                    filled: _hasRated && !_isEditing,
                                    fillColor: _hasRated && !_isEditing ? Colors.grey.shade50 : null,
                                    hintStyle: TextStyle(color: bodyTextColor.withOpacity(0.7)),
                                  ),
                                  style: TextStyle(color: bodyTextColor),
                                ),
                              ],
                              
                              SizedBox(height: 16),
                              
                              if (!_hasRated || _isEditing)
                                Row(
                                  children: [
                                    // Cancel button (shown only when editing)
                                    if (_isEditing) 
                                      Expanded(
                                        flex: 1,
                                        child: OutlinedButton(
                                          onPressed: () {
                                            setState(() {
                                              _isEditing = false;
                                              _userRating = _originalRating;
                                              _reviewController.text = _originalReview;
                                            });
                                          },
                                          style: OutlinedButton.styleFrom(
                                            padding: EdgeInsets.symmetric(vertical: 14),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            side: BorderSide(color: bodyTextColor.withOpacity(0.5)),
                                            foregroundColor: bodyTextColor,
                                          ),
                                          child: Text(
                                            'Cancel',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                      ),
                                    
                                    // Space between buttons when in edit mode
                                    if (_isEditing) SizedBox(width: 12),
                                    
                                    // Submit button
                                    Expanded(
                                      flex: _isEditing ? 2 : 4,
                                      child: ElevatedButton(
                                        onPressed: _isSubmittingRating ? null : _submitRating,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: _isEditing ? secondaryColor : primaryColor,
                                          foregroundColor: Colors.white,
                                          padding: EdgeInsets.symmetric(vertical: 14),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          elevation: 0,
                                        ),
                                        child: _isSubmittingRating
                                            ? SizedBox(
                                                height: 20,
                                                width: 20,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                                ),
                                              )
                                            : Text(
                                                _isEditing ? 'Update Rating' : 'Submit Rating',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 16,
                                                ),
                                              ),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 24),
                    
                    ],
                  ),
                ),
    );
  }
}