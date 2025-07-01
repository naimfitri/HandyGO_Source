import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import '../api_service.dart'; // Import API service

class BookingDetailPageUnpaid extends StatefulWidget {
  final String bookingId;
  final String userId;

  const BookingDetailPageUnpaid({
    Key? key,
    required this.bookingId,
    required this.userId,
  }) : super(key: key);

  @override
  _BookingDetailPageUnpaidState createState() => _BookingDetailPageUnpaidState();
}

class _BookingDetailPageUnpaidState extends State<BookingDetailPageUnpaid> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService(); // Create ApiService instance
  bool _isLoading = true;
  bool _isProcessingPayment = false;
  Map<String, dynamic> _bookingDetails = {};
  Map<String, dynamic> _invoiceDetails = {};
  Map<String, dynamic> _handymanDetails = {};
  Map<String, dynamic> _userDetails = {};
  String? _errorMessage;
  double walletBalance = 0.0;
  
  // Add controller and variables for custom slider
  late AnimationController _slideController;
  double _dragPosition = 0.0;
  double _dragPercentage = 0.0;
  bool _slideCompleted = false;

  @override
  void initState() {
    super.initState();
    _fetchBookingDetails();
    
    // Initialize the animation controller for the custom slider
    _slideController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
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
            print("Invoice data: $invoiceData"); // Debug print
            print("Invoice items: ${invoiceData['items']}"); // Debug print items specifically
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
        
        // Fetch user wallet balance using ApiService
        try {
          final walletResponse = await _apiService.getUserWallet(widget.userId);
          
          if (walletResponse.statusCode == 200) {
            final walletData = json.decode(walletResponse.body);
            setState(() {
              walletBalance = walletData['walletBalance']?.toDouble() ?? 0.0;
              _userDetails = walletData;
            });
          }
        } catch (e) {
          print('Error fetching wallet balance: $e');
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

  Future<void> _processPayment() async {
    // Calculate total amount due (service fee + items)
    double itemsTotal = 0.0;
    if (_invoiceDetails['items'] != null && _invoiceDetails['items'] is Map) {
      (_invoiceDetails['items'] as Map<String, dynamic>).forEach((key, item) {
        if (item is Map && item.containsKey('total')) {
          itemsTotal += (item['total'] is num) ? item['total'].toDouble() : 0.0;
        }
      });
    }
    
    double serviceFee = (_invoiceDetails['fare'] is num) 
        ? _invoiceDetails['fare'].toDouble() 
        : 0.0;
    
    final double totalAmount = serviceFee + itemsTotal;
    
    if (walletBalance < totalAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Insufficient wallet balance. Please top up your wallet.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    setState(() {
      _isProcessingPayment = true;
    });
    
    try {
      final response = await _apiService.processPayment(
        userId: widget.userId,
        bookingId: widget.bookingId,
        handymanId: _bookingDetails['assigned_to'],
        amount: totalAmount,
      );
      
      setState(() {
        _isProcessingPayment = false;
      });
      
      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        
        // Show success dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Text('Payment Successful'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  color: Colors.green,
                  size: 64,
                ),
                SizedBox(height: 16),
                const Text(
                  'Thank you for your payment!',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text('Amount: RM ${totalAmount.toStringAsFixed(2)}'),
                SizedBox(height: 8),
                Text('New wallet balance: RM ${result['newBalance'].toStringAsFixed(2)}'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context); // Return to bookings list
                },
                child: Text('OK'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to process payment: ${response.body}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isProcessingPayment = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error processing payment: $e'),
          backgroundColor: Colors.red,
        ),
      );
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

  Widget _buildInfoRow(String label, String value) {
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
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Replace the slider button implementation with custom slider
  Widget _buildSlideToPayButton() {
    final double sliderWidth = MediaQuery.of(context).size.width - 40;
    final double buttonSize = 55.0;
    
    // If payment is being processed, show loading state
    if (_isProcessingPayment) {
      return Container(
        width: sliderWidth,
        height: 60,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          color: Colors.grey.shade300,
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade800),
                  strokeWidth: 2,
                ),
              ),
              SizedBox(width: 16),
              Text(
                "Processing payment...",
                style: TextStyle(
                  color: Color(0xff4a4a4a),
                  fontWeight: FontWeight.w500,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Build custom slider
    return Container(
      width: sliderWidth,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        color: Colors.grey.shade300,
      ),
      child: Stack(
        children: [
          // Slide background with text
          Center(
            child: Text(
              "Slide to pay now",
              style: TextStyle(
                color: Color(0xff4a4a4a),
                fontWeight: FontWeight.w500,
                fontSize: 18,
              ),
            ),
          ),
          
          // Draggable button
          Positioned(
            left: _dragPosition,
            top: 2.5,
            child: GestureDetector(
              onHorizontalDragUpdate: (details) {
                setState(() {
                  _dragPosition += details.delta.dx;
                  // Constrain position within the slider width
                  _dragPosition = _dragPosition.clamp(0.0, sliderWidth - buttonSize);
                  _dragPercentage = _dragPosition / (sliderWidth - buttonSize);
                  
                  // If reached the end, trigger payment
                  if (_dragPercentage > 0.9 && !_slideCompleted) {
                    _slideCompleted = true;
                    _processPayment();
                  }
                });
              },
              onHorizontalDragEnd: (details) {
                if (_dragPercentage < 0.9) {
                  // Reset position if not completed
                  setState(() {
                    _dragPosition = 0.0;
                    _dragPercentage = 0.0;
                  });
                }
              },
              child: Container(
                width: buttonSize,
                height: 55.0,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color.fromARGB(255, 107, 110, 208),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4.0,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.payment,
                  color: Colors.white,
                  size: 30.0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Calculate total items cost
    double itemsTotal = 0.0;
    if (_invoiceDetails['items'] != null && _invoiceDetails['items'] is Map) {
      (_invoiceDetails['items'] as Map<String, dynamic>).forEach((key, item) {
        if (item is Map && item.containsKey('total')) {
          itemsTotal += (item['total'] is num) ? item['total'].toDouble() : 0.0;
        }
      });
    }

    // Get the service fee from the invoice
    double serviceFee = (_invoiceDetails['fare'] is num) 
        ? _invoiceDetails['fare'].toDouble() 
        : 0.0;

    // Calculate total amount (service fee + items)
    double totalAmount = serviceFee + itemsTotal;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Invoice'),
        backgroundColor: Colors.white,
        elevation: 1,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
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
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status Banner
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber, width: 1),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'PAYMENT REQUIRED',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber[800],
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Service completed - Please complete payment',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.amber[800],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 24),
                      
                      // Invoice Card
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
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Invoice',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '#${widget.bookingId.substring(0, 8)}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              Divider(),
                              SizedBox(height: 8),
                              
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Date',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                  Text(
                                    _invoiceDetails['createdAt'] != null 
                                        ? _formatDate(_invoiceDetails['createdAt'])
                                        : 'Unknown',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 16),
                              
                              // Service details
                              const Text(
                                'Service Details',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 8),
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
                              
                              SizedBox(height: 16),
                              Divider(),
                              SizedBox(height: 8),
                              
                              // Items list
                              const Text(
                                'Items / Materials',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 16),
                              
                              // Headers
                              const Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      'Item',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
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
                                      ),
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              Divider(height: 1),
                              
                              // Item rows
                              if (_invoiceDetails['items'] != null && _invoiceDetails['items'] is Map && (_invoiceDetails['items'] as Map).isNotEmpty)
                                ...(_invoiceDetails['items'] as Map<String, dynamic>).entries.map((entry) {
                                  final String itemId = entry.key;
                                  final Map<String, dynamic> item = entry.value;
                                  return Column(
                                    children: [
                                      SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Expanded(
                                            flex: 3,
                                            child: Text(
                                              item['itemName'] ?? 'Unknown item',
                                              style: TextStyle(
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 1,
                                            child: Text(
                                              '${item['quantity'] ?? 0}',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              'RM ${(item['pricePerUnit'] ?? 0).toStringAsFixed(2)}',
                                              textAlign: TextAlign.right,
                                              style: TextStyle(
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              'RM ${(item['total'] ?? 0).toStringAsFixed(2)}',
                                              textAlign: TextAlign.right,
                                              style: TextStyle(
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 8),
                                      Divider(height: 1),
                                    ],
                                  );
                                }).toList()
                              else
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.info_outline,
                                        color: Colors.blue[300],
                                        size: 24, 
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        'No materials or additional items for this service.',
                                        style: TextStyle(
                                          fontStyle: FontStyle.italic,
                                          color: Colors.grey[600],
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              
                              SizedBox(height: 16),
                              
                              // Summary
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Materials Subtotal',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    'RM ${itemsTotal.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Service Fee',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    'RM ${serviceFee.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 16),
                              Divider(),
                              SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Total Amount',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                  Text(
                                    'RM ${totalAmount.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: Colors.blue[800],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 24),
                      
                      // Wallet Balance Card
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Your Wallet Balance',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Available Balance',
                                    style: TextStyle(
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                  Text(
                                    'RM ${walletBalance.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green[700],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 24),
                      
                      // Replace the Payment Button with Slide-to-Pay Button
                      _buildSlideToPayButton(),
                      
                      SizedBox(height: 16),
                    ],
                  ),
                ),
    );
  }
}