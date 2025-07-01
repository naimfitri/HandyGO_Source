import 'package:firebase_database/firebase_database.dart';

class DatabaseService {
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  
  // Update handyman availability status
  Future<void> updateHandymanStatus(String userId, bool isAvailable) async {
    try {
      await _database.ref('handymen/$userId').update({
        'isAvailable': isAvailable,
        'lastStatusUpdate': ServerValue.timestamp,
      });
      
      // If becoming unavailable, remove from locations
      if (!isAvailable) {
        await _database.ref('handymen_locations/$userId').remove();
      }
    } catch (e) {
      print('Error updating handyman status: $e');
      rethrow;
    }
  }
  
  // Get handyman's current location
  Future<Map<String, dynamic>?> getHandymanLocation(String handymanId) async {
    try {
      final snapshot = await _database.ref('handymen_locations/$handymanId').get();
      if (snapshot.exists) {
        return Map<String, dynamic>.from(snapshot.value as Map);
      }
      return null;
    } catch (e) {
      print('Error getting handyman location: $e');
      return null;
    }
  }
}