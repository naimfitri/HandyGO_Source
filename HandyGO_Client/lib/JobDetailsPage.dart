import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class JobDetailsPage extends StatefulWidget {
  final String jobId;
  
  const JobDetailsPage({Key? key, required this.jobId}) : super(key: key);

  @override
  _JobDetailsPageState createState() => _JobDetailsPageState();
}

class _JobDetailsPageState extends State<JobDetailsPage> {
  bool _isLoading = true;
  Map<String, dynamic>? jobData;
  String? errorMessage;
  
  @override
  void initState() {
    super.initState();
    _fetchJobDetails();
  }
  
  Future<void> _fetchJobDetails() async {
    try {
      final snapshot = await FirebaseDatabase.instance
        .ref()
        .child('jobs')
        .child(widget.jobId)
        .once();
        
      if (snapshot.snapshot.value != null) {
        setState(() {
          jobData = Map<String, dynamic>.from(snapshot.snapshot.value as Map);
          _isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'Job not found';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Job Details'),
      ),
      body: _isLoading 
        ? Center(child: CircularProgressIndicator())
        : errorMessage != null
          ? Center(child: Text(errorMessage!))
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Status: ${jobData!['status']}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _getStatusColor(jobData!['status']),
                            ),
                          ),
                          SizedBox(height: 12),
                          Text('Category: ${jobData!['category'] ?? 'N/A'}', 
                              style: TextStyle(fontSize: 16)),
                          SizedBox(height: 8),
                          Text('Description: ${jobData!['description'] ?? 'No description'}',
                              style: TextStyle(fontSize: 16)),
                          SizedBox(height: 8),
                          Text('Address: ${jobData!['address'] ?? 'No address'}',
                              style: TextStyle(fontSize: 16)),
                          SizedBox(height: 12),
                          Text('Booking Time:',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          Text('Start: ${_formatTimestamp(jobData!['starttimestamp'])}'),
                          Text('End: ${_formatTimestamp(jobData!['endtimestamp'])}'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
  
  Color _getStatusColor(String status) {
    switch (status) {
      case 'Accepted': return Colors.green;
      case 'Rejected': return Colors.red;
      case 'In-Progress': return Colors.blue;
      case 'Completed': return Colors.purple;
      case 'Completed-Paid': return Colors.purple;
      default: return Colors.grey;
    }
  }
  
  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Not scheduled';
    
    try {
      if (timestamp is String) {
        return DateTime.parse(timestamp).toString().substring(0, 16);
      }
      // Handle other timestamp formats if needed
      return timestamp.toString();
    } catch (e) {
      return 'Invalid date';
    }
  }
}