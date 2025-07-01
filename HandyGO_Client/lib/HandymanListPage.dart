import 'package:flutter/material.dart';
import 'dart:convert';
import 'booking_page.dart';
import 'HandymanReviewsPage.dart';
import 'api_service.dart'; // Add this import

class HandymanListPage extends StatefulWidget {
  final String category;
  final String userName;
  final String userEmail;
  final String userId;

  const HandymanListPage({
    Key? key, 
    required this.category,
    required this.userName,
    required this.userEmail,
    required this.userId
  }) : super(key: key);

  @override
  _HandymanListPageState createState() => _HandymanListPageState();
}

class _HandymanListPageState extends State<HandymanListPage> {
  final ApiService _apiService = ApiService(); // Create instance of ApiService
  List<Map<String, dynamic>> handymen = [];
  bool isLoading = true;
  String error = '';
  String? userCity;
  bool _showAllCities = false;

  @override
  void initState() {
    super.initState();
    _getUserCity().then((_) => fetchHandymen());
  }

  Future<void> _getUserCity() async {
    try {
      final response = await _apiService.getUserAddress(widget.userId);

      if (response.statusCode == 200) {
        final addressData = json.decode(response.body);
        setState(() {
          userCity = addressData['city'] ?? '';
        });
      } else {
        print('Failed to fetch user city: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching user city: $e');
    }
  }

  @override
  void didUpdateWidget(HandymanListPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.category != widget.category) {
      fetchHandymen();
    }
  }

  Future<void> fetchHandymen() async {
    setState(() {
      isLoading = true;
      error = '';
    });

    try {
      final response = await _apiService.getHandymen(
        widget.category,
        city: !_showAllCities && userCity != null && userCity!.isNotEmpty ? userCity : null
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          handymen = List<Map<String, dynamic>>.from(data);
          isLoading = false;
        });
      } else {
        setState(() {
          error = 'Failed to load handymen: ${response.statusCode}';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = 'Error: $e';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          "${widget.category} Specialists",
          style: TextStyle(
            color: Colors.grey[800], 
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: Colors.grey[800], size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          _buildLocationFilter(),
          Expanded(
            child: isLoading
                ? _buildLoadingState()
                : error.isNotEmpty
                    ? _buildErrorState()
                    : handymen.isEmpty
                        ? _buildEmptyState()
                        : _buildHandymenList(),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationFilter() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: [
          Icon(Icons.location_on, color: Colors.blue[700], size: 18),
          SizedBox(width: 8),
          Text(
            'Location:',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              userCity ?? 'Unknown location',
              style: TextStyle(
                color: Colors.grey[700],
                fontWeight: FontWeight.w400,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          GestureDetector(
            onTap: () {
              setState(() {
                _showAllCities = !_showAllCities;
                fetchHandymen();
              });
            },
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _showAllCities ? Colors.blue[50] : Colors.grey[100],
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _showAllCities ? Colors.blue[300]! : Colors.grey[300]!,
                  width: 1,
                ),
              ),
              child: Text(
                _showAllCities ? 'All Cities' : 'Only $userCity',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: _showAllCities ? Colors.blue[700] : Colors.grey[700],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[700]!),
            strokeWidth: 3,
          ),
          SizedBox(height: 20),
          Text(
            'Finding specialists...',
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Container(
        padding: EdgeInsets.all(24),
        margin: EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 15,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.red[400],
              size: 56,
            ),
            SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: fetchHandymen,
              icon: Icon(Icons.refresh),
              label: Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        padding: EdgeInsets.all(32),
        margin: EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 15,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              color: Colors.amber[700],
              size: 64,
            ),
            SizedBox(height: 24),
            Text(
              'No ${widget.category} specialists found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12),
            Text(
              _showAllCities
                  ? 'No specialists are available at the moment.'
                  : 'Try expanding your search to all cities.',
              style: TextStyle(
                color: Colors.grey[600],
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            if (!_showAllCities) ...[
              SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _showAllCities = true;
                    fetchHandymen();
                  });
                },
                icon: Icon(Icons.public),
                label: Text('Show All Cities'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHandymenList() {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      physics: BouncingScrollPhysics(),
      itemCount: handymen.length,
      itemBuilder: (context, index) {
        final handyman = handymen[index];
        return _buildHandymanCard(context, handyman);
      },
    );
  }

  Widget _buildHandymanCard(BuildContext context, Map<String, dynamic> handyman) {
    final String name = handyman['name'] ?? 'Unknown';
    final String handymanId = handyman['id'] ?? '';
    
    final double rating = handyman['rating'] is double
        ? handyman['rating']
        : (handyman['average_rating'] is double 
            ? handyman['average_rating'] 
            : double.tryParse(handyman['average_rating']?.toString() ?? handyman['rating']?.toString() ?? '0') ?? 0.0);
    
    
    final String city = handyman['city'] ?? 'Unknown location';
    final List<String> expertise = handyman['expertise'] is List
        ? List<String>.from(handyman['expertise'])
        : [];
    final int experience = handyman['experience'] is int
        ? handyman['experience']
        : int.tryParse(handyman['experience'].toString()) ?? 0;
    
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.grey[200],
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 5,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: FutureBuilder<Map<String, dynamic>>(
                      future: _apiService.fetchProfileImageHandyman(handymanId),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[400]!),
                              ),
                            ),
                          );
                        } else if (snapshot.hasData && snapshot.data!['success'] == true) {
                          return Image.network(
                            snapshot.data!['imageUrl'],
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              print('Error loading handyman image: $error');
                              return Icon(
                                Icons.person,
                                size: 40,
                                color: Colors.grey[600],
                              );
                            },
                          );
                        } else {
                          return Icon(
                            Icons.person,
                            size: 40,
                            color: Colors.grey[600],
                          );
                        }
                      },
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      SizedBox(height: 6),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => HandymanReviewsPage(
                                handymanId: handyman['id'],
                                handymanName: name,
                              ),
                            ),
                          );
                        },
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.amber[50],
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.amber[200]!),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.star, color: Colors.amber[700], size: 14),
                                  SizedBox(width: 4),
                                  Text(
                                    rating.toStringAsFixed(1),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.amber[800],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Check reviews',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue[600],
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.location_on, color: Colors.blue[700], size: 14),
                          SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              city,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, thickness: 1, color: Colors.grey[100]),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.work_outline, color: Colors.blue[700], size: 16),
                          ),
                          SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                experience > 0 ? '$experience years' : 'New',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[800],
                                ),
                              ),
                              Text(
                                'Experience',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.check_circle_outline, color: Colors.green[700], size: 16),
                          ),
                          SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              FutureBuilder<int>(
                                future: _getCompletedJobsCount(handyman['id']),
                                builder: (context, snapshot) {
                                  return Text(
                                    snapshot.hasData ? snapshot.data.toString() : '0',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[800],
                                    ),
                                  );
                                },
                              ),
                              Text(
                                'Jobs done',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                if (expertise.isNotEmpty) ...[
                  SizedBox(
                    height: 30,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: expertise.map((skill) {
                        return Container(
                          margin: EdgeInsets.only(right: 8),
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Text(
                            skill,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[800],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  SizedBox(height: 16),
                ],
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      _showBookingBottomSheet(context, handyman);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Book Now',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateCard(Map<String, dynamic> day, bool isSelected, bool allSlotsBooked, Function() onTap) {
    final date = day['date'] as DateTime;
    
    return Opacity(
      opacity: allSlotsBooked ? 0.5 : 1.0,
      child: GestureDetector(
        onTap: allSlotsBooked ? null : onTap,
        child: Container(
          width: 80,
          margin: EdgeInsets.only(right: 10),
          decoration: BoxDecoration(
            gradient: isSelected 
                ? LinearGradient(
                    colors: [Colors.blue[700]!, Colors.blue[500]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isSelected ? null : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: isSelected 
                    ? Colors.blue.withOpacity(0.3) 
                    : Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              Container(
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      day['dayName'] as String,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.grey[700],
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      '${date.day}',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : Colors.grey[800],
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      day['monthName'] as String,
                      style: TextStyle(
                        fontSize: 12,
                        color: isSelected ? Colors.white.withOpacity(0.9) : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              if (allSlotsBooked)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.grey.withOpacity(0.1),
                    ),
                    child: Center(
                      child: Transform.rotate(
                        angle: 0.3,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            border: Border.all(color: Colors.red.withOpacity(0.3)),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'FULL',
                            style: TextStyle(
                              color: Colors.red[700],
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBookingBottomSheet(BuildContext context, Map<String, dynamic> handyman) {
    String? selectedDay;
    String? selectedTimeSlot;
    bool isLoading = true;
    Map<String, Set<String>> bookedSlots = {};
    
    final now = DateTime.now();
    final days = List.generate(7, (index) {
      final date = now.add(Duration(days: index));
      final formattedDate = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
      return {
        'date': date,
        'dayName': _getDayName(date.weekday),
        'dayOfMonth': date.day,
        'monthName': _getMonthName(date.month),
        'formattedDate': formattedDate,
      };
    });
    
    final timeSlots = [
      {'id': '1', 'time': '8:00 AM - 12:00 PM'},
      {'id': '2', 'time': '1:00 PM - 5:00 PM'},
      {'id': '3', 'time': '6:00 PM - 10:00 PM'},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            if (isLoading) {
              // Debug the handyman ID to ensure it's correctly passed
              print('Loading slots for handyman ID: ${handyman['id']}');
              
              fetchBookedSlots(handyman['id']).then((slots) {
                // Add debug output to see what slots we're getting
                print('Received booked slots: $slots');
                
                setState(() {
                  bookedSlots = slots;
                  isLoading = false;
                });
              });
            }

            // Debug the current booking state
            bool anyDaysFullyBooked = false;
            if (!isLoading) {
              days.forEach((day) {
                final date = day['formattedDate'] as String;
                final slotsForDay = bookedSlots[date] ?? {};
                if (slotsForDay.length >= 3) {
                  anyDaysFullyBooked = true;
                  print('Day $date is fully booked: ${bookedSlots[date]}');
                } else if (slotsForDay.isNotEmpty) {
                  print('Day $date has booked slots: ${bookedSlots[date]}');
                }
              });
              
              if (!anyDaysFullyBooked) {
                print('No fully booked days found');
              }
            }

            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: Offset(0, -5),
                  ),
                ],
              ),
              child: isLoading
                  ? Center(child: CircularProgressIndicator())
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 10,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.calendar_month,
                                  color: Colors.blue[700],
                                ),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Book Appointment',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey[800],
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'with ${handyman['name'] ?? 'Specialist'}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.close, color: Colors.grey[700]),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Padding(
                              padding: EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Select Date',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[800],
                                    ),
                                  ),
                                  SizedBox(height: 16),
                                  Container(
                                    height: 110,
                                    child: ListView.builder(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: days.length,
                                      itemBuilder: (context, index) {
                                        final day = days[index];
                                        final formattedDate = day['formattedDate'] as String;
                                        final isSelected = selectedDay == formattedDate;
                                        
                                        // Improved logging for debugging booked slots
                                        final slotsForDay = bookedSlots[formattedDate] ?? {};
                                        print('Date: $formattedDate, Booked Slots: $slotsForDay');
                                        
                                        // Check if all slots are booked (more robust check)
                                        final allSlotsBooked = slotsForDay.contains('1') && 
                                                             slotsForDay.contains('2') && 
                                                             slotsForDay.contains('3');
                                        
                                        if (allSlotsBooked) {
                                          print('All slots booked for $formattedDate: $slotsForDay');
                                        }
                                        
                                        return _buildDateCard(
                                          day,
                                          isSelected,
                                          allSlotsBooked,
                                          () {
                                            setState(() {
                                              selectedDay = formattedDate;
                                              selectedTimeSlot = null;
                                              // Print available slots for selected day
                                              print('Selected day: $formattedDate with booked slots: ${bookedSlots[formattedDate]}');
                                            });
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                  SizedBox(height: 30),
                                  if (selectedDay != null) ...[
                                    Text(
                                      'Select Time',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey[800],
                                      ),
                                    ),
                                    SizedBox(height: 16),
                                    Column(
                                      children: timeSlots.map((slot) {
                                        final slotId = slot['id'] as String;
                                        final isSelected = selectedTimeSlot == slotId;
                                        final isBooked = bookedSlots[selectedDay]?.contains(slotId) ?? false;
                                        
                                        return Opacity(
                                          opacity: isBooked ? 0.5 : 1.0,
                                          child: GestureDetector(
                                            onTap: isBooked ? null : () {
                                              setState(() {
                                                selectedTimeSlot = slotId;
                                              });
                                            },
                                            child: Container(
                                              margin: EdgeInsets.only(bottom: 10),
                                              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                              decoration: BoxDecoration(
                                                color: isSelected ? Colors.blue[50] : Colors.white,
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: isSelected ? Colors.blue[300]! : Colors.grey[300]!,
                                                ),
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.access_time,
                                                    color: isSelected ? Colors.blue[700] : Colors.grey[600],
                                                    size: 20,
                                                  ),
                                                  SizedBox(width: 12),
                                                  Text(
                                                    slot['time'] ?? '',
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.w500,
                                                      color: isSelected ? Colors.blue[700] : Colors.grey[800],
                                                    ),
                                                  ),
                                                  Spacer(),
                                                  if (isSelected)
                                                    Icon(
                                                      Icons.check_circle,
                                                      color: Colors.blue[700],
                                                      size: 20,
                                                    ),
                                                  if (isBooked)
                                                    Container(
                                                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                      decoration: BoxDecoration(
                                                        color: Colors.red[50],
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                      child: Text(
                                                        'Booked',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: Colors.red[800],
                                                          fontWeight: FontWeight.w500,
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: Offset(0, -5),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Container(
                              // Remove AnimatedContainer and use regular Container with fixed width
                              // This prevents the constraint interpolation errors
                              width: MediaQuery.of(context).size.width * 0.85,
                              child: ElevatedButton(
                                onPressed: (selectedDay != null && selectedTimeSlot != null)
                                    ? () {
                                        // Add a try-catch block to help debug navigation issues
                                        try {
                                          // Pop the modal first
                                          Navigator.pop(context);
                                          
                                          // Small delay to ensure modal is closed before navigation
                                          Future.delayed(Duration(milliseconds: 100), () {
                                            String timeSlot = timeSlots.firstWhere(
                                              (slot) => slot['id'] == selectedTimeSlot
                                            )['time'] ?? '';
                                            
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => BookingPage(
                                                  category: widget.category,
                                                  userName: widget.userName,
                                                  userEmail: widget.userEmail,
                                                  userId: widget.userId,
                                                  handymanId: handyman['id'],
                                                  handymanName: handyman['name'] ?? 'Unknown',
                                                  selectedDate: selectedDay!,
                                                  selectedTimeSlot: _getSlotNameFromId(selectedTimeSlot!),
                                                ),
                                              ),
                                            );
                                          });
                                        } catch (e) {
                                          print("Navigation error: $e");
                                          // Show a snackbar if there's an error
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text("Error proceeding to booking: $e"))
                                          );
                                        }
                                      }
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue[700],
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor: Colors.grey[200],
                                  disabledForegroundColor: Colors.grey[400],
                                  elevation: (selectedDay != null && selectedTimeSlot != null) ? 2 : 0,
                                  shadowColor: Colors.blue.withOpacity(0.3),
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: (selectedDay != null && selectedTimeSlot != null)
                                    ? Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            padding: EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Colors.blue.shade600,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.check,
                                              color: Colors.white,
                                              size: 16,
                                            ),
                                          ),
                                          SizedBox(width: 12),
                                          Text(
                                            'Confirm Booking',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      )
                                    : Text(
                                        'Select date and time',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            );
          },
        );
      },
    );
  }
  
  String _getDayName(int weekday) {
    switch (weekday) {
      case 1: return 'Mon';
      case 2: return 'Tue';
      case 3: return 'Wed';
      case 4: return 'Thu';
      case 5: return 'Fri';
      case 6: return 'Sat';
      case 7: return 'Sun';
      default: return '';
    }
  }
  
  String _getMonthName(int month) {
    switch (month) {
      case 1: return 'Jan';
      case 2: return 'Feb';
      case 3: return 'Mar';
      case 4: return 'Apr';
      case 5: return 'May';
      case 6: return 'Jun';
      case 7: return 'Jul';
      case 8: return 'Aug';
      case 9: return 'Sep';
      case 10: return 'Oct';
      case 11: return 'Nov';
      case 12: return 'Dec';
      default: return '';
    }
  }

  // Replace the _getCompletedJobsCount method with a type-safe implementation
  Future<int> _getCompletedJobsCount(String handymanId) async {
    try {
      // Try to get jobs assigned to this handyman
      final response = await _apiService.getHandymanJobsCompleted(handymanId);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        int count = 0;

        // Handle different response formats
        if (data.containsKey('jobs')) {
          final jobs = data['jobs'];
          if (jobs is List) {
            // Handle List format
            for (var job in jobs) {
              if (job is Map && 
                  job['assigned_to'] == handymanId && 
                  job['status'] == 'Completed-Paid') {
                count++;
              }
            }
          } else if (jobs is Map) {
            // Handle Map format
            jobs.forEach((jobId, job) {
              if (job is Map && 
                  job['assigned_to'] == handymanId && 
                  job['status'] == 'Completed-Paid') {
                count++;
              }
            });
          }
        }

        print('Found $count completed jobs for handyman: $handymanId');
        return count;
      } else {
        print('Primary API failed, trying fallback...');
        // Fallback to get all jobs and filter manually
        final fallbackResponse = await _apiService.getAllJobs();

        if (fallbackResponse.statusCode == 200) {
          final allJobs = json.decode(fallbackResponse.body);
          int count = 0;

          // Handle both List and Map formats
          if (allJobs is List) {
            for (var job in allJobs) {
              if (job is Map && 
                  job['assigned_to'] == handymanId && 
                  job['status'] == 'Completed-Paid') {
                count++;
              }
            }
          } else if (allJobs is Map) {
            allJobs.forEach((jobId, job) {
              if (job is Map && 
                  job['assigned_to'] == handymanId && 
                  job['status'] == 'Completed-Paid') {
                count++;
              }
            });
          }

          print('Using fallback method: Found $count completed jobs for handyman: $handymanId');
          return count;
        }

        // If all attempts fail
        return 0;
      }
    } catch (e) {
      print('Error getting completed jobs count: $e');
      return 0;
    }
  }

}

// Update standalone functions to use ApiService
Future<Map<String, Set<String>>> fetchBookedSlots(String handymanId) async {
  Map<String, Set<String>> bookedSlots = {};
  final ApiService apiService = ApiService();
  
  try {
    print('Fetching booked slots for handyman: $handymanId');
    
    final response = await apiService.getHandymanSlots(handymanId);
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      print('Booked slots response: $data');
      
      if (data['bookedSlots'] != null) {
        // Ensure we're properly processing the response format
        final responseSlots = data['bookedSlots'] as Map<String, dynamic>;
        responseSlots.forEach((date, slots) {
          if (slots is List<dynamic>) {
            // Handle array format
            bookedSlots[date] = Set<String>.from(slots);
          } else if (slots is Map<String, dynamic>) {
            // Handle object format if backend sends it differently
            final slotSet = <String>{};
            slots.forEach((slotId, isBooked) {
              if (isBooked == true) slotSet.add(slotId);
            });
            bookedSlots[date] = slotSet;
          }
          
          // Debug the processed slots
          print('Processed booked slots for $date: ${bookedSlots[date]}');
        });
      }
      
      return bookedSlots;
    } else {
      print('Failed to fetch booked slots: ${response.statusCode} - ${response.body}');
      return {};
    }
  } catch (e) {
    print('Error fetching booked slots: $e');
    return {};
  }
}

Future<Map<String, Map<String, bool>>> fetchHandymanJobs(String handymanId) async {
  Map<String, Map<String, bool>> occupiedSlots = {};
  final ApiService apiService = ApiService();
  
  try {
    final response = await apiService.getHandymanJobs(handymanId);
    
    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      
      if (data.containsKey('jobs')) {
        final jobs = data['jobs'] as Map<String, dynamic>;
        
        jobs.forEach((jobId, jobData) {
          if (jobData['assigned_to'] == handymanId) {
            final startTimestamp = DateTime.parse(jobData['starttimestamp']);
            final dateStr = "${startTimestamp.year}-${startTimestamp.month.toString().padLeft(2, '0')}-${startTimestamp.day.toString().padLeft(2, '0')}";
            final slotId = _getSlotIdFromName(jobData['assigned_slot']);
            
            if (!occupiedSlots.containsKey(dateStr)) {
              occupiedSlots[dateStr] = {
                '1': false,
                '2': false,
                '3': false,
              };
            }
            
            if (slotId != null) {
              occupiedSlots[dateStr]![slotId] = true;
            }
          }
        });
      }
      
      return occupiedSlots;
    } else {
      print('Failed to fetch handyman jobs: ${response.statusCode}');
      return {};
    }
  } catch (e) {
    print('Error fetching handyman jobs: $e');
    return {};
  }
}

String? _getSlotIdFromName(String slotName) {
  switch (slotName) {
    case 'Slot 1': return '1';
    case 'Slot 2': return '2';
    case 'Slot 3': return '3';
    default: return null;
  }
}

String _getSlotNameFromId(String slotId) {
  switch (slotId) {
    case '1': return 'Slot 1';
    case '2': return 'Slot 2';
    case '3': return 'Slot 3';
    default: return 'Unknown Slot';
  }
}

Future<Map<String, Map<String, bool>>> fetchHandymanAvailability(String handymanId) async {
  final ApiService apiService = ApiService();
  
  try {
    print('Fetching availability for handyman: $handymanId');
    
    final response = await apiService.getHandymanAvailability(handymanId);
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      print('Availability response: $data');
      
      final Map<String, Map<String, bool>> availability = {};
      
      if (data['availability'] != null) {
        (data['availability'] as Map<String, dynamic>).forEach((date, slots) {
          availability[date] = Map<String, bool>.from(slots as Map<String, dynamic>);
        });
      }
      
      print('Processed availability: $availability');
      return availability;
    } else {
      print('Failed to fetch availability: ${response.statusCode}, ${response.body}');
      return _generateDefaultAvailability();
    }
  } catch (e) {
    print('Error fetching availability: $e');
    return _generateDefaultAvailability();
  }
}

Map<String, Map<String, bool>> _generateDefaultAvailability() {
  final now = DateTime.now();
  final Map<String, Map<String, bool>> defaultAvailability = {};
  
  for (int i = 0; i < 7; i++) {
    final date = now.add(Duration(days: i));
    final dateStr = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    
    defaultAvailability[dateStr] = {
      '1': true,
      '2': true,
      '3': true,
    };
  }
  
  return defaultAvailability;
}