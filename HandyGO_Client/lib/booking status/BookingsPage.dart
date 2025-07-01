import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'BookingDetailPage.dart';
import 'BookingDetailPageAccepted.dart';
import 'BookingDetailPageInProgress.dart';
import 'BookingDetailPageUnpaid.dart';
import 'BookingDetailPagePaid.dart';
import 'BookingDetailPagePending.dart';
import '../api_service.dart'; // Import the API service
import 'BookingDetailPageRejected.dart';
import 'BookingDetailPageCancel.dart';
import 'BookingDetailPageExpired.dart'; // Add import for new page

class BookingsPage extends StatefulWidget {
  final String userId;

  const BookingsPage({
    Key? key,
    required this.userId,
  }) : super(key: key);

  @override
  _BookingsPageState createState() => _BookingsPageState();
}

class _BookingsPageState extends State<BookingsPage> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService(); // Create instance of ApiService
  bool _isLoading = true;
  List<Map<String, dynamic>> _bookings = [];
  List<Map<String, dynamic>> _activeBookings = []; // For completed-unpaid
  List<Map<String, dynamic>> _completedBookings = []; // For completed-paid
  String? _errorMessage;
  final double PROCESSING_FEE = 15.0; // Define the processing fee as a constant
  double walletBalance = 0.0; // To store the user's wallet balance
  bool _isLoadingWallet = true;
  String? _walletError;
  late TabController _tabController;
  
  // Add filter state variable
  String _activeFilter = 'all'; // Possible values: 'all', 'pending', 'accepted', 'in-progress', 'completed-unpaid'
  String _historyFilter = 'all'; // Possible values: 'all', 'completed-paid', 'rejected', 'cancelled', 'expired'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchBookings();
    _loadUserWalletBalance(); // Fetch wallet balance when page loads
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchBookings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _apiService.getUserBookings(widget.userId);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<Map<String, dynamic>> allBookings = [];
        final List<Map<String, dynamic>> activeBookings = [];
        final List<Map<String, dynamic>> completedBookings = [];
        
        for (var bookingData in data['bookings']) {
          final booking = Map<String, dynamic>.from(bookingData);
          
          // If there's a handyman assigned but no name, fetch the handyman details
          if (booking['assigned_to'] != null && 
              (booking['handyman_name'] == null || booking['handyman_name'] == 'Unassigned')) {
            try {
              final handymanResponse = await _apiService.getHandyman(booking['assigned_to']);
              
              if (handymanResponse.statusCode == 200) {
                final handymanData = json.decode(handymanResponse.body);
                booking['handyman_name'] = handymanData['name'] ?? 'Unknown';
              }
            } catch (e) {
              print('Error fetching handyman details: $e');
            }
          }
          
          allBookings.add(booking);
          
          // Updated categorization based on status
          final status = (booking['status'] ?? '').toLowerCase();
          
          // Active bookings: completed-unpaid, pending, in-progress, accepted
          if (status == 'completed-unpaid' || 
              status == 'pending' || 
              status == 'in-progress' || 
              status == 'accepted') {
            activeBookings.add(booking);
          } 
          // Completed bookings: completed-paid, rejected, canceled
          else if (status == 'completed-paid' || 
                   status == 'rejected' || 
                   status == 'canceled' ||
                   status == 'cancelled' ||  // Add British spelling variant
                   status == 'expired') {
            completedBookings.add(booking);
          }
        }
        
        // Sort bookings by date (newest first)
        activeBookings.sort((a, b) {
          if (a['starttimestamp'] == null || b['starttimestamp'] == null) return 0;
          return DateTime.parse(b['starttimestamp']).compareTo(DateTime.parse(a['starttimestamp']));
        });
        
        completedBookings.sort((a, b) {
          if (a['starttimestamp'] == null || b['starttimestamp'] == null) return 0;
          return DateTime.parse(b['starttimestamp']).compareTo(DateTime.parse(a['starttimestamp']));
        });
        
        setState(() {
          _bookings = allBookings;
          _activeBookings = activeBookings;
          _completedBookings = completedBookings;
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

  Future<void> _loadUserWalletBalance() async {
    try {
      final response = await _apiService.getUserWallet(widget.userId);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          walletBalance = data['walletBalance']?.toDouble() ?? 0.0;
          _isLoadingWallet = false;
        });
      } else {
        setState(() {
          _walletError = 'Failed to load wallet balance';
          _isLoadingWallet = false;
        });
      }
    } catch (e) {
      setState(() {
        _walletError = 'Error: $e';
        _isLoadingWallet = false;
      });
    }
  }

  String _formatDate(String timestamp) {
    try {
      final DateTime date = DateTime.parse(timestamp);
      return DateFormat('EEE, MMM d, yyyy').format(date);
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
      case 'accepted':
        return Colors.green;
      case 'in progress':
      case 'in-progress':
        return Colors.blue;
      case 'cancelled':
      case 'canceled':
        return Colors.red;
      case 'rejected':
        return Colors.redAccent;
      case 'expired':
        return Colors.brown.shade700;
      case 'completed-unpaid':
        return Colors.amber;
      case 'completed-paid':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  void _navigateToBookingDetail(String bookingId, String status) {
    if (status.toLowerCase() == 'pending') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BookingDetailPagePending(
            bookingId: bookingId,
            userId: widget.userId,
          ),
        ),
      );
    } else if (status.toLowerCase() == 'accepted') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BookingDetailPageAccepted(
            bookingId: bookingId,
            userId: widget.userId,
          ),
        ),
      );
    } else if (status.toLowerCase() == 'in-progress') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BookingDetailPageInProgress(
            bookingId: bookingId,
            userId: widget.userId,
          ),
        ),
      );
    } else if (status.toLowerCase() == 'completed-unpaid') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BookingDetailPageUnpaid(
            bookingId: bookingId,
            userId: widget.userId,
          ),
        ),
      ).then((_) => _fetchBookings()); // Refresh after returning
    } else if (status.toLowerCase() == 'completed-paid') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BookingDetailPagePaid(
            bookingId: bookingId,
            userId: widget.userId,
          ),
        ),
      );
    } else if (status.toLowerCase() == 'rejected') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BookingDetailPageRejected(
            bookingId: bookingId,
            userId: widget.userId,
          ),
        ),
      );
    } else if (status.toLowerCase() == 'cancelled' || status.toLowerCase() == 'canceled') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BookingDetailPageCancel(
            bookingId: bookingId,
            userId: widget.userId,
          ),
        ),
      );
    } else if (status.toLowerCase() == 'expired') {
      // For expired bookings
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BookingDetailPageExpired(
            bookingId: bookingId,
            userId: widget.userId,
          ),
        ),
      );
    } else {
      // Default case
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BookingDetailPage(
            bookingId: bookingId,
            userId: widget.userId,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F6FC),
      appBar: AppBar(
        title: Text(
          'My Bookings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.blue,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.grey,
          tabs: [
            Tab(
              icon: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.pending_actions),
                  SizedBox(width: 8),
                  Text('Active'),
                  if (_activeBookings.isNotEmpty)
                    Container(
                      margin: EdgeInsets.only(left: 5),
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _activeBookings.length.toString(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Tab(
              icon: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history),
                  SizedBox(width: 8),
                  Text('History'),
                  if (_completedBookings.isNotEmpty)
                    Container(
                      margin: EdgeInsets.only(left: 5),
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.teal,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _completedBookings.length.toString(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
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
                        onPressed: _fetchBookings,
                        child: Text('Retry'),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    // Active Tab (Completed but Unpaid)
                    _buildBookingsList(_activeBookings, 'completed-unpaid'),
                    
                    // Completed Tab (Completed and Paid)
                    _buildBookingsList(_completedBookings, 'completed-paid'),
                  ],
                ),
    );
  }

  Widget _buildBookingsList(List<Map<String, dynamic>> bookings, String sectionType) {
    // Apply filter for active bookings and history
    List<Map<String, dynamic>> filteredBookings = bookings;
    if (sectionType == 'completed-unpaid' && _activeFilter != 'all') {
      filteredBookings = bookings.where((booking) => 
        (booking['status'] ?? '').toLowerCase() == _activeFilter).toList();
    } else if (sectionType == 'completed-paid' && _historyFilter != 'all') {
      if (_historyFilter == 'cancelled') {
        // Special case for cancelled to handle both spelling variants
        filteredBookings = bookings.where((booking) {
          final status = (booking['status'] ?? '').toLowerCase();
          return status == 'cancelled' || status == 'canceled';
        }).toList();
      } else {
        // Normal filtering for other statuses
        filteredBookings = bookings.where((booking) => 
          (booking['status'] ?? '').toLowerCase() == _historyFilter).toList();
      }
    }

    // Build a column that includes filter buttons for active tab and history tab
    return Column(
      children: [
        // Show filter buttons based on which tab we're viewing
        if (sectionType == 'completed-unpaid')
          _buildFilterButtons(),
        
        // Add filters for history tab
        if (sectionType == 'completed-paid')
          _buildHistoryFilterButtons(),
          
        // Show content based on whether we have bookings or not
        Expanded(
          child: RefreshIndicator(
            onRefresh: _fetchBookings,
            child: filteredBookings.isEmpty
              ? ListView(  // Make empty state scrollable for RefreshIndicator to work
                  children: [
                    Container(
                      height: MediaQuery.of(context).size.height * 0.6,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              sectionType == 'completed-unpaid' ? Icons.pending_actions : Icons.history,
                              size: 80,
                              color: Colors.grey[300],
                            ),
                            SizedBox(height: 16),
                            Text(
                              sectionType == 'completed-unpaid'
                                  ? (_activeFilter == 'all' 
                                      ? 'No active bookings' 
                                      : 'No ${_formatStatusText(_activeFilter)} bookings')
                                  : (_historyFilter == 'all'
                                      ? 'No booking history yet'
                                      : 'No ${_formatStatusText(_historyFilter)} bookings'),
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[700],
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              sectionType == 'completed-unpaid'
                                  ? (_activeFilter == 'all'
                                      ? 'Pending, accepted, in-progress and unpaid bookings will appear here'
                                      : '${_formatStatusText(_activeFilter)} bookings will appear here')
                                  : (_historyFilter == 'all'
                                      ? 'Completed, paid, rejected or canceled bookings will appear here'
                                      : '${_formatStatusText(_historyFilter)} bookings will appear here'),
                              style: TextStyle(
                                color: Colors.grey[600],
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              : ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: filteredBookings.length,
                  itemBuilder: (context, index) {
                    final booking = filteredBookings[index];
                    return _buildBookingCard(context, booking);
                  },
                ),
          ),
        ),
      ],
    );
  }

  // Add new method for history filter buttons
  Widget _buildHistoryFilterButtons() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildHistoryFilterButton('All', 'all'),
          SizedBox(width: 8),
          _buildHistoryFilterButton('Completed', 'completed-paid'),
          SizedBox(width: 8),
          _buildHistoryFilterButton('Rejected', 'rejected'),
          SizedBox(width: 8),
          _buildHistoryFilterButton('Cancelled', 'cancelled'),
          SizedBox(width: 8),
          _buildHistoryFilterButton('Expired', 'expired'),
        ],
      ),
    );
  }

  Widget _buildHistoryFilterButton(String label, String filterValue) {
    final bool isSelected = _historyFilter == filterValue;
    
    return ElevatedButton(
      onPressed: () {
        setState(() {
          _historyFilter = filterValue;
        });
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? Colors.teal : Colors.white,
        foregroundColor: isSelected ? Colors.white : Colors.black,
        elevation: isSelected ? 2 : 0,
        side: BorderSide(color: isSelected ? Colors.teal : Colors.grey.shade300),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      child: Text(label),
    );
  }

  Widget _buildFilterButtons() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildFilterButton('All', 'all'),
          SizedBox(width: 8),
          _buildFilterButton('Pending', 'pending'),
          SizedBox(width: 8),
          _buildFilterButton('Accepted', 'accepted'),
          SizedBox(width: 8),
          _buildFilterButton('In Progress', 'in-progress'),
          SizedBox(width: 8),
          _buildFilterButton('Payment Required', 'completed-unpaid'),
        ],
      ),
    );
  }

  Widget _buildFilterButton(String label, String filterValue) {
    final bool isSelected = _activeFilter == filterValue;
    
    return ElevatedButton(
      onPressed: () {
        setState(() {
          _activeFilter = filterValue;
        });
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? Colors.blue : Colors.white,
        foregroundColor: isSelected ? Colors.white : Colors.black,
        elevation: isSelected ? 2 : 0,
        side: BorderSide(color: isSelected ? Colors.blue : Colors.grey.shade300),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      child: Text(label),
    );
  }

  Widget _buildBookingCard(BuildContext context, Map<String, dynamic> booking) {
    final startDate = booking['starttimestamp'] != null 
        ? _formatDate(booking['starttimestamp']) 
        : 'Unknown date';
    
    final startTime = booking['starttimestamp'] != null 
        ? _formatTime(booking['starttimestamp']) 
        : '';
    
    final endTime = booking['endtimestamp'] != null 
        ? _formatTime(booking['endtimestamp']) 
        : '';
    
    final timeRange = '$startTime - $endTime';
    final status = booking['status'] ?? 'Unknown';
    final category = booking['category'] ?? 'General Service';
    
    // Update handyman name retrieval to also check assigned_to
    String handymanName = booking['handyman_name'] ?? 'Unassigned';
    if (handymanName == 'Unassigned' && booking['assigned_to'] != null) {
      handymanName = "ID: ${booking['assigned_to']}";
    }
    
    final bookingId = booking['booking_id'] ?? '';
    final isCompletedUnpaid = status.toLowerCase() == 'completed-unpaid';

    return Card(
      margin: EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        // Add a colored border for payment required bookings
        side: isCompletedUnpaid 
            ? BorderSide(color: Colors.amber, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: () {
          _navigateToBookingDetail(bookingId, status);
        },
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            // Header with status color
            Container(
              decoration: BoxDecoration(
                color: _getStatusColor(status).withOpacity(0.1),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      category,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status).withOpacity(0.8),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _formatStatusText(status),
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Booking details
            Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                      SizedBox(width: 8),
                      Text(
                        startDate,
                        style: TextStyle(
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 16, color: Colors.grey),
                      SizedBox(width: 8),
                      Text(
                        timeRange,
                        style: TextStyle(
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.person, size: 16, color: Colors.grey),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          handymanName == 'Unassigned' 
                              ? 'Handyman: Not yet assigned'
                              : 'Handyman: $handymanName',
                          style: TextStyle(
                            color: handymanName == 'Unassigned' ? Colors.orange : Colors.grey[700],
                            fontStyle: handymanName == 'Unassigned' ? FontStyle.italic : FontStyle.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  
                  // Add price information if available
                  if (booking['price'] != null) ...[
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.monetization_on, size: 16, color: Colors.grey),
                        SizedBox(width: 8),
                        Text(
                          'RM ${booking['price']?.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                  
                  // Add action based on status
                  SizedBox(height: 16),
                  _buildActionButtonForStatus(booking, bookingId, status),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Add this new method to your class
  Widget _buildActionButtonForStatus(Map<String, dynamic> booking, String bookingId, String status) {
    final statusLower = status.toLowerCase();
    
    // For completed-unpaid, show payment button
    if (statusLower == 'completed-unpaid') {
      return ElevatedButton(
        onPressed: () {
          _navigateToBookingDetail(bookingId, status);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.amber,
          foregroundColor: Colors.white,
          minimumSize: Size(double.infinity, 40),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Text('Make Payment'),
      );
    }
    
    // For pending, show cancel option
    else if (statusLower == 'pending') {
      return ElevatedButton(
        onPressed: () {
          _navigateToBookingDetail(bookingId, status);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
          minimumSize: Size(double.infinity, 40),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Text('View Details'),
      );
    }
    
    // For accepted
    else if (statusLower == 'accepted') {
      return ElevatedButton(
        onPressed: () {
          _navigateToBookingDetail(bookingId, status);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          minimumSize: Size(double.infinity, 40),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Text('Track Service'),
      );
    }
    
    // For in-progress
    else if (statusLower == 'in-progress') {
      return ElevatedButton(
        onPressed: () {
          _navigateToBookingDetail(bookingId, status);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          minimumSize: Size(double.infinity, 40),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Text('View Progress'),
      );
    }
    
    // For all completed, rejected, canceled statuses
    else {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            'View Details',
            style: TextStyle(
              color: Colors.blue,
              fontSize: 12,
            ),
          ),
          Icon(
            Icons.arrow_forward_ios,
            size: 12,
            color: Colors.blue,
          ),
        ],
      );
    }
  }

  String _formatStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Pending';
      case 'accepted':
        return 'Accepted';
      case 'in-progress':
        return 'In Progress';
      case 'completed-unpaid':
        return 'Payment Required';
      case 'completed-paid':
        return 'Completed & Paid';
      case 'rejected':
        return 'Rejected';
      case 'cancelled':
        return 'Canceled';
      case 'expired':
        return 'Expired';
      default:
        return status;
    }
  }
}