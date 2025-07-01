const admin = require('firebase-admin');
const express = require('express');
const cors = require('cors');


// Initialize Express Router instead of app
const router = express.Router();
router.use(cors());
router.use(express.json());

// Reference to the database
const db = admin.database();

// This will track the job statuses we've already processed
const processedJobStatusChanges = new Map();

// Improved helper function to check if notification was already sent
async function wasNotificationSent(jobId, status) {
  try {
    // Check in database if this notification was already sent
    const notifRef = db.ref(`notification_history/${jobId}_${status}_user`);
    const snapshot = await notifRef.once('value');
    return snapshot.exists();
  } catch (error) {
    console.error('Error checking notification history:', error);
    // Fall back to memory map if database check fails
    return processedJobStatusChanges.has(`${jobId}-${status}`);
  }
}

// Helper function to mark notification as sent
async function markNotificationSent(jobId, status) {
  try {
    // Store in database that this notification was sent
    await db.ref(`notification_history/${jobId}_${status}_user`).set({
      sentAt: admin.database.ServerValue.TIMESTAMP,
      recipient: 'user'
    });
    // Also keep in memory map as backup
    processedJobStatusChanges.set(`${jobId}-${status}`, Date.now());
  } catch (error) {
    console.error('Error updating notification history:', error);
    // At least update the memory map
    processedJobStatusChanges.set(`${jobId}-${status}`, Date.now());
  }
}

// Set up interval to check for job status changes
setInterval(async () => {
  try {
    // Get all jobs
    const jobsSnapshot = await db.ref('/jobs').once('value');
    const jobs = jobsSnapshot.val();
    
    if (!jobs) return;
    
    // Process each job
    for (const jobId in jobs) {
      const job = jobs[jobId];
      
      // Skip if no status or user_id
      if (!job.status || !job.user_id) continue;
      
      // Skip if we've already processed this status for this job
      if (await wasNotificationSent(jobId, job.status)) continue;
      
      // Send notification based on status
      if (['Accepted', 'Rejected', 'In-Progress', 'Completed-Unpaid'].includes(job.status)) {
        const success = await sendJobStatusNotification(job, jobId);
        if (success) {
          // Mark as processed only if notification was sent successfully
          await markNotificationSent(jobId, job.status);
        }
      }
    }
    
    // Clean up old entries from memory map (older than 1 hour)
    const now = Date.now();
    for (const [key, timestamp] of processedJobStatusChanges.entries()) {
      if (now - timestamp > 3600000) {
        processedJobStatusChanges.delete(key);
      }
    }
  } catch (error) {
    console.error('Error checking job statuses:', error);
  }
}, 10000); // Check every 10 seconds

// Function to send job status notifications to users
async function sendJobStatusNotification(job, jobId) {
  try {
    const userId = job.user_id;
    
    // Get user's FCM token
    const userSnapshot = await db.ref(`/users/${userId}/fcmToken`).once('value');
    const userToken = userSnapshot.val();
    
    if (!userToken) {
      console.log(`No FCM token for user ${userId}`);
      return false;
    }
    
    // Prepare notification based on status
    let title = '';
    let body = '';
    
    switch (job.status) {
      case 'Accepted':
        title = 'Job Request Accepted';
        body = 'Your service request has been accepted by a handyman';
        break;
      case 'Rejected':
        title = 'Job Request Rejected';
        body = 'We\'re sorry, your service request was rejected';
        break;
      case 'In-Progress':
        title = 'Job Started';
        body = 'Your service is now in progress';
        break;
      case 'Completed-Unpaid':
        title = 'Job Completed';
        body = 'Your service has been completed. Please complete the payment to finalize the service.';
        break;
      default:
        title = 'Booking Status Update';
        body = `Your booking status has been updated to ${job.status}`;
    }
    
    // Send the notification
    const message = {
      token: userToken,
      notification: {
        title: title,
        body: body,
      },
      data: {
        jobId: jobId,
        status: job.status,
        click_action: 'FLUTTER_NOTIFICATION_CLICK'
      }
    };
    
    await admin.messaging().send(message);
    console.log(`Sent job status notification to user ${userId} for job ${jobId}: ${title}`);
    
    // Return true to indicate success
    return true;
  } catch (error) {
    console.error('Error sending job status notification:', error);
    return false;
  }
}

// This will track handyman location checks
const handymenLocationChecks = new Map();
// Track arrivals to avoid duplicate notifications
const handymanArrivalNotified = new Map();

// Set up interval to check for handyman arrivals
setInterval(async () => {
  try {
    const checkStartTime = Date.now();
    console.log('Checking for handyman arrivals...');
    
    // Get all handymen locations with a timeout
    const locationsPromise = db.ref('/handymen_locations').once('value');
    const locationsSnapshot = await Promise.race([
      locationsPromise,
      new Promise((_, reject) => setTimeout(() => reject(new Error('Timeout fetching locations')), 5000))
    ]);
    
    const locations = locationsSnapshot.val();
    
    if (!locations) {
      console.log('No handyman locations found');
      return;
    }
    
    // Get all jobs with a timeout
    const jobsPromise = db.ref('/jobs').once('value');
    const jobsSnapshot = await Promise.race([
      jobsPromise,
      new Promise((_, reject) => setTimeout(() => reject(new Error('Timeout fetching jobs')), 5000))
    ]);
    
    const jobs = jobsSnapshot.val();
    
    if (!jobs) {
      console.log('No jobs found');
      return;
    }
    
    console.log(`Found ${Object.keys(locations).length} handyman locations and ${Object.keys(jobs).length} jobs`);
    let checkedPairs = 0;
    
    // Process each handyman location with limits
    for (const handymanId in locations) {
      const location = locations[handymanId];
      
      // Find this handyman's active jobs (limit to 10 jobs maximum to avoid hang)
      const handymanJobs = Object.entries(jobs)
        .filter(([_, job]) => job.assigned_to === handymanId && job.status === 'In-Progress')
        .slice(0, 10);
      
      if (handymanJobs.length === 0) continue;
      
      for (const [jobId, job] of handymanJobs) {
        checkedPairs++;
        
        // Skip if this arrival has already been notified (using both memory map and database check)
        const arrivalKey = `${handymanId}-${jobId}`;
        if (handymanArrivalNotified.has(arrivalKey)) continue;
        if (job.handymanArrivalNotified) continue;
        
        // Better validation for coordinates
        if (!job.latitude || !job.longitude || !location.latitude || !location.longitude) {
          continue;
        }
        
        try {
          // Check if handyman is near the job location - use improved calculation with safety checks
          const distance = calculateDistance(
            parseFloat(job.latitude), parseFloat(job.longitude),
            parseFloat(location.latitude), parseFloat(location.longitude)
          );
          
          // If within 100 meters (0.1 km) and we haven't recently checked
          const checkKey = `${handymanId}-${jobId}`;
          const lastCheck = handymenLocationChecks.get(checkKey) || 0;
          const now = Date.now();
          
          if (distance <= 0.1 && (now - lastCheck > 60000)) { // Don't check more than once per minute
            handymenLocationChecks.set(checkKey, now);
            handymanArrivalNotified.set(arrivalKey, now);
            
            // Update job to mark arrival as notified
            await db.ref(`/jobs/${jobId}`).update({
              handymanArrivalNotified: true,
              handymanArrivalTime: now
            });
            
            // Send notification
            await sendHandymanArrivalNotification(job, jobId, handymanId);
          }
        } catch (calcError) {
          console.error(`Error processing arrival check for job ${jobId}, handyman ${handymanId}:`, calcError);
          continue;
        }
      }
    }
    
    const elapsedTime = Date.now() - checkStartTime;
    console.log(`Completed handyman arrival checks: Processed ${checkedPairs} job-handyman pairs in ${elapsedTime}ms`);
    
  } catch (error) {
    console.error('Error checking handyman locations:', error);
  }
}, 20000); // Check every 20 seconds

// Improved helper function for calculating distance (using Haversine formula)
function calculateDistance(lat1, lon1, lat2, lon2) {
  // Ensure all parameters are valid numbers
  if ([lat1, lon1, lat2, lon2].some(coord => typeof coord !== 'number' || isNaN(coord))) {
    return 9999; // Return large distance for invalid coordinates
  }
  
  try {
    const R = 6371; // Radius of the Earth in kilometers
    const dLat = deg2rad(lat2 - lat1);
    const dLon = deg2rad(lon2 - lon1);
    const a = 
      Math.sin(dLat/2) * Math.sin(dLat/2) +
      Math.cos(deg2rad(lat1)) * Math.cos(deg2rad(lat2)) * 
      Math.sin(dLon/2) * Math.sin(dLon/2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a)); 
    const d = R * c; // Distance in km
    
    return isFinite(d) ? d : 9999;
  } catch (error) {
    console.error('Error calculating distance:', error);
    return 9999;
  }
}

// Helper function to convert degrees to radians
function deg2rad(deg) {
  return deg * (Math.PI / 180);
}

// Helper function to send handyman arrival notification
async function sendHandymanArrivalNotification(job, jobId, handymanId) {
  try {
    const userId = job.user_id;
    
    if (!userId) {
      console.log(`No user ID found for job ${jobId}`);
      return false;
    }
    
    // Get user's FCM token
    const userSnapshot = await db.ref(`/users/${userId}/fcmToken`).once('value');
    const userToken = userSnapshot.val();
    
    if (!userToken) {
      console.log(`No FCM token found for user ${userId}`);
      return false;
    }
    
    // Get handyman name
    let handymanName = "Your handyman";
    const handymanSnapshot = await db.ref(`/handymen/${handymanId}`).once('value');
    if (handymanSnapshot.exists()) {
      const handymanData = handymanSnapshot.val();
      handymanName = handymanData.name || "Your handyman";
    }
    
    // Send the notification
    const message = {
      token: userToken,
      notification: {
        title: 'Handyman Has Arrived',
        body: `${handymanName} has arrived at your location.`,
      },
      data: {
        jobId: jobId,
        handymanId: handymanId,
        type: 'handyman_arrival',
        click_action: 'FLUTTER_NOTIFICATION_CLICK'
      }
    };
    
    await admin.messaging().send(message);
    console.log(`Sent handyman arrival notification to user ${userId} for job ${jobId}`);
    return true;
  } catch (error) {
    console.error('Error sending handyman arrival notification:', error);
    return false;
  }
}

// API endpoint to check server status
router.get('/status', (req, res) => {
  res.json({ status: 'online', timestamp: new Date() });
});

// Test endpoint to send FCM notifications
router.post('/test-notification', async (req, res) => {
  try {
    const { token, jobId = 'test-job-id', status = 'Accepted' } = req.body;
    
    if (!token) {
      return res.status(400).json({ error: 'FCM token is required' });
    }
    
    // Create notification message
    let title = '';
    let body = '';
    
    switch (status) {
      case 'Accepted':
        title = 'Job Request Accepted';
        body = 'Your service request has been accepted by a handyman';
        break;
      case 'Rejected':
        title = 'Job Request Rejected';
        body = 'We\'re sorry, your service request was rejected';
        break;
      case 'In-Progress':
        title = 'Job Started';
        body = 'Your service is now in progress';
        break;
      case 'Completed-Unpaid':
        title = 'Job Completed';
        body = 'Your service has been completed but payment is pending';
        break;
      default:
        title = 'Test Notification';
        body = 'This is a test notification';
    }
    
    const message = {
      token: token,
      notification: {
        title: title,
        body: body,
      },
      data: {
        jobId: jobId,
        status: status,
        click_action: 'FLUTTER_NOTIFICATION_CLICK'
      }
    };
    
    // Send the notification
    const response = await admin.messaging().send(message);
    console.log('Successfully sent test notification:', response);
    
    res.json({ 
      success: true, 
      message: 'Notification sent successfully',
      response 
    });
  } catch (error) {
    console.error('Error sending test notification:', error);
    res.status(500).json({ 
      success: false, 
      error: error.message 
    });
  }
});

// Add another endpoint to simulate arrivals
router.post('/test-arrival', async (req, res) => {
  try {
    const { token, jobId = 'test-job-id', handymanId = 'test-handyman-id' } = req.body;
    
    if (!token) {
      return res.status(400).json({ error: 'FCM token is required' });
    }
    
    const message = {
      token: token,
      notification: {
        title: 'Handyman Has Arrived',
        body: 'Your handyman has arrived at the location',
      },
      data: {
        jobId: jobId,
        handymanId: handymanId,
        click_action: 'FLUTTER_NOTIFICATION_CLICK'
      }
    };
    
    const response = await admin.messaging().send(message);
    console.log('Successfully sent arrival test notification:', response);
    
    res.json({ 
      success: true, 
      message: 'Arrival notification sent successfully',
      response 
    });
  } catch (error) {
    console.error('Error sending arrival test notification:', error);
    res.status(500).json({ 
      success: false, 
      error: error.message 
    });
  }
});

// Add an endpoint to modify job status
router.post('/update-job-status', async (req, res) => {
  try {
    const { jobId, status } = req.body;
    
    if (!jobId || !status) {
      return res.status(400).json({ error: 'JobId and status are required' });
    }
    
    // Update the job status in the database
    await db.ref(`/jobs/${jobId}`).update({
      status: status
    });
    
    res.json({ 
      success: true, 
      message: `Job ${jobId} status updated to ${status}` 
    });
  } catch (error) {
    console.error('Error updating job status:', error);
    res.status(500).json({ 
      success: false, 
      error: error.message 
    });
  }
});

// Add this endpoint to handle FCM token uploads - add before "Start the server" line
router.post('/register-fcm-token', async (req, res) => {
  try {
    const { userId, token, userType = 'users' } = req.body;
    
    // Validate required fields
    if (!userId || !token) {
      return res.status(400).json({ 
        success: false, 
        error: 'User ID and FCM token are required' 
      });
    }
    
    // Update the FCM token in the database
    await db.ref(`/${userType}/${userId}`).update({
      fcmToken: token,
      lastTokenUpdate: new Date().toISOString()
    });
    
    console.log(`FCM token updated for ${userType} ${userId}: ${token.substring(0, 15)}...`);
    
    res.json({
      success: true,
      message: `FCM token updated successfully`
    });
  } catch (error) {
    console.error('Error updating FCM token:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

// Optionally add a helper function to send handyman arrival notifications
// if it doesn't already exist
async function sendHandymanArrivalNotification(job, jobId, handymanId) {
  try {
    const userId = job.user_id;
    
    // Get user's FCM token
    const userSnapshot = await db.ref(`/users/${userId}/fcmToken`).once('value');
    const userToken = userSnapshot.val();
    
    if (!userToken) {
      console.log(`No FCM token for user ${userId}`);
      return;
    }
    
    // Send the notification
    const message = {
      token: userToken,
      notification: {
        title: 'Handyman Has Arrived',
        body: 'Your service provider has arrived at the location',
      },
      data: {
        jobId: jobId,
        handymanId: handymanId,
        click_action: 'FLUTTER_NOTIFICATION_CLICK'
      }
    };
    
    await admin.messaging().send(message);
    console.log(`Sent handyman arrival notification to user ${userId} for job ${jobId}`);
  } catch (error) {
    console.error('Error sending handyman arrival notification:', error);
  }
}

// Add endpoint to get handyman image from Firebase Storage
router.get('/images/:handymanId', async (req, res) => {
  try {
    const { handymanId } = req.params;
    
    if (!handymanId) {
      return res.status(400).json({
        success: false,
        error: 'Handyman ID is required'
      });
    }
    
    console.log(`⚠️ Fetching profile image for handyman: ${handymanId}`);
    
    try {
      const bucket = admin.storage().bucket();
      const fileName = `profile_handyman/${handymanId}.jpg`;
      
      // Check if image exists in storage
      const [exists] = await bucket.file(fileName).exists();
      
      if (!exists) {
        console.log(`❌ Image not found in storage: ${fileName}`);
        return res.status(404).json({
          success: false,
          error: 'Image not found'
        });
      }
      
      // Generate signed URL valid for 15 minutes
      const [url] = await bucket.file(fileName).getSignedUrl({
        action: 'read',
        expires: Date.now() + 15 * 60 * 1000, // 15 minutes
      });
      
      console.log(`✅ Generated signed URL for image: ${url}`);
      
      return res.status(200).json({
        success: true,
        imageUrl: url
      });
      
    } catch (storageError) {
      console.error('❌ Firebase Storage error:', storageError);
      
      // Try to get image URL from Realtime Database
      const snapshot = await admin.database()
        .ref(`handymen/${handymanId}`)
        .once('value');
      
      if (!snapshot.exists()) {
        return res.status(404).json({
          success: false,
          error: 'Handyman not found'
        });
      }
      
      const handymanData = snapshot.val();
      const profileImage = handymanData.profileImage;
      
      if (!profileImage) {
        return res.status(404).json({
          success: false,
          error: 'No profile image found for this handyman'
        });
      }
      
      console.log(`✅ Returning profile image from database for handyman: ${handymanId}`);
      
      return res.status(200).json({
        success: true,
        imageUrl: profileImage,
        fromDatabase: true
      });
    }
  } catch (error) {
    console.error('❌ Error fetching image:', error);
    return res.status(500).json({
      success: false,
      error: `Failed to fetch image: ${error.message}`
    });
  }
});

// Export the router instead of starting the server
module.exports = router;