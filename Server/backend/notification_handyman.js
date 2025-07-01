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
    const notifRef = db.ref(`notification_history/${jobId}_${status}_handyman`);
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
    await db.ref(`notification_history/${jobId}_${status}_handyman`).set({
      sentAt: admin.database.ServerValue.TIMESTAMP,
      recipient: 'handyman'
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
      
      // Skip if no status or assigned_to
      if (!job.status || !job.assigned_to) continue;
      
      // Skip if we've already processed this status for this job
      if (await wasNotificationSent(jobId, job.status)) continue;
      
      // Send notification based on status to handyman
      if (['Pending', 'Completed-Paid'].includes(job.status)) {
        const success = await sendJobStatusNotificationHandymen(job, jobId);
        if (success) {
          // Mark as processed only if notification was sent successfully
          await markNotificationSent(jobId, job.status);
        }
      }
    }
    
    // Clean up old entries (older than 1 hour)
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

// Function to send job status notifications
async function sendJobStatusNotificationHandymen(job, jobId) {
  try {
    const userId = job.assigned_to;
    
    // Get user's FCM token
    const userSnapshot = await db.ref(`/handymen/${userId}/fcmToken`).once('value');
    const userToken = userSnapshot.val();
    
    if (!userToken) {
      console.log(`No FCM token for user ${userId}`);
      return;
    }
    
    // Prepare notification based on status
    let title = '';
    let body = '';
    
    switch (job.status) {
      case 'Pending':
        title = 'New Job Request';
        body = `You have a new job request from ${job.user_id}`;
        break;
      case 'Completed-Paid':
        title = 'Payment Received';
        body = `Payment for job ${jobId} has been received`;
        break;
      default:
        return;
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
    console.log(`Sent job status notification to user ${userId} for job ${jobId}`);
    
    // Return true if notification was sent successfully
    return true;
  } catch (error) {
    console.error('Error sending job status notification:', error);
    return false;
  }
}

// API endpoint to check server status
router.get('/status', (req, res) => {
  res.json({ status: 'online', timestamp: new Date() });
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
    const { userId, token, userType = 'handymen' } = req.body;
    
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

// Export the router instead of starting the server
module.exports = router;