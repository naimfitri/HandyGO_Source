/**
 * System Automation for HandyGo Backend
 * 
 * This file handles automated tasks related to the booking system:
 * - Checking for expired booking requests
 * - Auto-canceling bookings that handymen haven't responded to
 * - Cleaning up past bookings
 * - Issuing refunds when necessary
 */

const admin = require('firebase-admin');
const express = require('express');
const cors = require('cors');
const { DateTime } = require('luxon'); // Add Luxon import

// Initialize Express Router
const router = express.Router();
router.use(cors());
router.use(express.json());

// Reference to the database
const db = admin.database();

// Constants for timing
const BOOKING_EXPIRY_HOURS = 2; // Request expires after 2 hours if no response
const JOB_AUTO_COMPLETE_HOURS = 24; // Job auto-completes 24 hours after scheduled end time if not marked
const CHECK_INTERVAL_MINUTES = 10; // Run checks every 10 minutes

// Helper function to get current date/time in Malaysia timezone (UTC+8)
function getMalaysiaTime() {
  return DateTime.now().setZone('Asia/Kuala_Lumpur');
}

// Helper function to format date to Malaysia time string
function formatMalaysiaTime(date) {
  if (date instanceof Date) {
    // Convert JS Date to Luxon DateTime
    return DateTime.fromJSDate(date).setZone('Asia/Kuala_Lumpur').toISO();
  } else if (date instanceof DateTime) {
    // If already a Luxon DateTime
    return date.setZone('Asia/Kuala_Lumpur').toISO();
  }
  // Default fallback
  return DateTime.now().setZone('Asia/Kuala_Lumpur').toISO();
}

// Helper function to send user notifications
async function sendUserNotification(userId, title, body, data = {}) {
  try {
    // Get user's FCM token
    const userSnapshot = await db.ref(`/users/${userId}/fcmToken`).once('value');
    const userToken = userSnapshot.val();
    
    if (!userToken) {
      console.log(`No FCM token for user ${userId}`);
      return false;
    }
    
    // Send the notification
    const message = {
      token: userToken,
      notification: {
        title: title,
        body: body,
      },
      data: {
        ...data,
        click_action: 'FLUTTER_NOTIFICATION_CLICK'
      }
    };
    
    await admin.messaging().send(message);
    console.log(`Sent notification to user ${userId}: ${title}`);
    return true;
  } catch (error) {
    console.error('Error sending notification:', error);
    return false;
  }
}

// Helper function to process refunds
async function processRefund(bookingId, userId) {
  try {
    console.log(`Processing refund for booking ${bookingId} to user ${userId}`);
    
    // First, search for the original booking-fee transaction to get the exact amount
    const transactionsSnapshot = await db.ref('walletTransactions')
      .orderByChild('bookingId')
      .equalTo(bookingId)
      .once('value');
    
    let processingFee = 0;
    let originalTransaction = null;
    
    // Find the original booking-fee transaction
    if (transactionsSnapshot.exists()) {
      transactionsSnapshot.forEach(snapshot => {
        const transaction = snapshot.val();
        if (transaction.transactionType === 'booking-fee' && 
            transaction.userId === userId) {
          originalTransaction = transaction;
          // Transaction amount is stored as negative, take the absolute value for refund
          processingFee = Math.abs(transaction.amount);
          console.log(`Found original booking fee transaction: ${processingFee} for booking ${bookingId}`);
          return true; // Break the forEach loop
        }
      });
    }
    
    // If no transaction found, fall back to booking data or global fare
    if (!originalTransaction) {
      console.log(`No original transaction found for booking ${bookingId}, using fallback`);
      
      // Get the booking information
      const bookingRef = db.ref(`jobs/${bookingId}`);
      const bookingSnapshot = await bookingRef.once('value');
      
      if (!bookingSnapshot.exists()) {
        console.error(`Booking ${bookingId} not found for refund`);
        return false;
      }
      
      const bookingData = bookingSnapshot.val();
      
      // Find the processing fee amount from booking or global fare
      if (bookingData.processing_fee) {
        processingFee = parseFloat(bookingData.processing_fee);
      } else {
        // If not specified in booking, get the global fare amount
        const fareSnapshot = await db.ref('fare').once('value');
        const fareData = fareSnapshot.val();
        processingFee = fareData?.amount || 15; // Default to 15 if not found
      }
    }
    
    // Get user's current wallet balance
    const userRef = db.ref(`users/${userId}`);
    const userSnapshot = await userRef.once('value');
    
    if (!userSnapshot.exists()) {
      console.error(`User ${userId} not found for refund`);
      return false;
    }
    
    const userData = userSnapshot.val();
    const currentWalletBalance = userData.wallet || 0;
    
    // Update user's wallet with refund
    const newWalletBalance = currentWalletBalance + processingFee;
    await userRef.update({
      wallet: newWalletBalance
    });
    
    // Record the refund transaction
    const transactionRef = db.ref('walletTransactions').push();
    await transactionRef.set({
      userId: userId,
      amount: processingFee, // Positive to indicate refund
      timestamp: admin.database.ServerValue.TIMESTAMP,
      transactionType: 'auto-refund',
      bookingId,
      description: `Automatic refund for ${originalTransaction ? 'exact' : 'estimated'} processing fee for booking ${bookingId}`
    });
    
    console.log(`Successfully processed refund of ${processingFee} for booking ${bookingId}`);
    return true;
  } catch (error) {
    console.error(`Error processing refund for booking ${bookingId}:`, error);
    return false;
  }
}

// Check for expired booking requests (no response from handyman)
async function checkExpiredBookingRequests() {
  try {
    console.log('Checking for expired booking requests...');
    
    // Get all pending jobs
    const jobsRef = db.ref('jobs');
    const snapshot = await jobsRef.orderByChild('status').equalTo('Pending').once('value');
    
    if (!snapshot.exists()) {
      console.log('No pending bookings found');
      return;
    }
    
    // Get Malaysian current time using Luxon for proper timezone handling
    const now = getMalaysiaTime();
    const currentHour = now.hour;
    const currentMinute = now.minute;
    const currentDate = now.toFormat('yyyy-MM-dd');
    
    console.log(`Current time (Malaysia): ${now.toFormat('yyyy-MM-dd HH:mm:ss')}`);
    let expiredCount = 0;
    
    // Check each pending booking
    snapshot.forEach((childSnapshot) => {
      const bookingId = childSnapshot.key;
      const booking = childSnapshot.val();
      
      // Calculate how long ago the booking was created
      const createdAt = booking.created_at ? 
        DateTime.fromISO(booking.created_at) : 
        now.minus({ hours: 0 });
        
      const hoursElapsed = now.diff(createdAt, 'hours').hours;
      
      console.log(`Booking ${bookingId}: created ${hoursElapsed.toFixed(2)} hours ago at ${createdAt.toISO()}`);
      
      // Case 2: If starttimestamp is in the future but booking request is older than the expiry time
      if (booking.starttimestamp) {

        const rawTime = booking.starttimestamp; // "2025-06-03T08:00:00.000Z"

        // Force interpret the time as MYT (ignore the Z conversion)
        const startDateTime = DateTime.fromFormat(
          rawTime.replace('Z', ''), // Remove Z so Luxon doesn't treat it as UTC
          "yyyy-MM-dd'T'HH:mm:ss.SSS", // Format without timezone
          { zone: 'Asia/Kuala_Lumpur' } // Treat this as local Malaysia time
        );

        // OR: If you want 08:00 to mean Malaysia 8am regardless of what's in the Z
        // const startDateTime = DateTime.fromISO("2025-06-03T08:00:00.000", { zone: 'Asia/Kuala_Lumpur' });

        const bookingDate = startDateTime.toFormat('yyyy-MM-dd');
        const bookingHour = startDateTime.hour;
        const bookingMinute = startDateTime.minute;
        
        console.log(`Booking ${bookingId}: Raw timestamp: ${booking.starttimestamp}`);
        console.log(`Extracted components: Date=${bookingDate}, Time=${bookingHour}:${bookingMinute}`);
        console.log(`Current components: Date=${currentDate}, Time=${currentHour}:${currentMinute}`);
        
        // Compare dates first, then times if dates are equal
        let isStartInFuture = false;
        
        if (bookingDate > currentDate) {
          // If booking date is after current date, it's in the future
          isStartInFuture = true;
        } else if (bookingDate === currentDate) {
          // If same date, compare time
          const bookingTimeMinutes = bookingHour * 60 + bookingMinute;
          const currentTimeMinutes = currentHour * 60 + currentMinute;
          isStartInFuture = bookingTimeMinutes > currentTimeMinutes;
        }
        
        console.log(`Booking ${bookingId} start time is ${isStartInFuture ? 'in future' : 'in past or now'}`);
        
        if (isStartInFuture && hoursElapsed > BOOKING_EXPIRY_HOURS) {
          console.log(`Case 2: Booking ${bookingId} has future start time but expired (${hoursElapsed.toFixed(2)} hours old)`);
          
          // Process in an async function to avoid blocking
          (async () => {
            // Update booking status
            await db.ref(`jobs/${bookingId}`).update({
              status: 'expired',
              auto_expired_at: now.toISO(),
              expiry_reason: `No response within ${BOOKING_EXPIRY_HOURS} hours`
            });
            
            // Issue refund to user
            const refundSuccess = await processRefund(bookingId, booking.user_id);
            
            // Notify user
            if (refundSuccess) {
              await sendUserNotification(
                booking.user_id,
                'Booking Request Expired',
                `Your booking request has expired as it was not accepted within ${BOOKING_EXPIRY_HOURS} hours. A refund of the processing fee has been issued to your wallet.`,
                { bookingId, type: 'booking_expired' }
              );
            }
            
            expiredCount++;
          })();
        }
      }
    });
    
    console.log(`Processed ${expiredCount} expired booking requests`);
  } catch (error) {
    console.error('Error checking expired booking requests:', error);
  }
}

// Check for past bookings that should be auto-completed
async function checkPastBookings() {
  try {
    console.log('Checking for past bookings that need auto-completion...');
    
    // This functionality has been removed as requested
    console.log('Auto-completion feature is disabled');
    return;
    
    // Original auto-completion code removed
  } catch (error) {
    console.error('Error checking past bookings:', error);
  }
}

// Check for booking requests scheduled in the past
async function checkPastScheduledBookings() {
  try {
    console.log('Checking for booking requests with past start times...');
    
    // Get all pending jobs
    const jobsRef = db.ref('jobs');
    const snapshot = await jobsRef.orderByChild('status').equalTo('Pending').once('value');
    
    if (!snapshot.exists()) {
      console.log('No pending bookings found');
      return;
    }
    
    // Get Malaysian current time using Luxon for proper timezone handling
    const now = getMalaysiaTime();
    const currentHour = now.hour;
    const currentMinute = now.minute;
    const currentDate = now.toFormat('yyyy-MM-dd');
    
    console.log(`Current time (Malaysia): ${now.toFormat('yyyy-MM-dd HH:mm:ss')}`);
    let pastBookingsCount = 0;
    
    // Check each pending booking
    snapshot.forEach((childSnapshot) => {
      const bookingId = childSnapshot.key;
      const booking = childSnapshot.val();
      
      // Case 1: Check if booking has a start timestamp in the past
      if (booking.starttimestamp) {
        // Extract date and time components from the booking timestamp
        const rawTime = booking.starttimestamp; // "2025-06-03T08:00:00.000Z"

        // Force interpret the time as MYT (ignore the Z conversion)
        const startDateTime = DateTime.fromFormat(
          rawTime.replace('Z', ''), // Remove Z so Luxon doesn't treat it as UTC
          "yyyy-MM-dd'T'HH:mm:ss.SSS", // Format without timezone
          { zone: 'Asia/Kuala_Lumpur' } // Treat this as local Malaysia time
        );

        // OR: If you want 08:00 to mean Malaysia 8am regardless of what's in the Z
        // const startDateTime = DateTime.fromISO("2025-06-03T08:00:00.000", { zone: 'Asia/Kuala_Lumpur' });

        const bookingDate = startDateTime.toFormat('yyyy-MM-dd');
        const bookingHour = startDateTime.hour;
        const bookingMinute = startDateTime.minute;
        
        console.log(`Booking ${bookingId}: Raw timestamp: ${booking.starttimestamp}`);
        console.log(`Extracted components: Date=${bookingDate}, Time=${bookingHour}:${bookingMinute}`);
        console.log(`Current components: Date=${currentDate}, Time=${currentHour}:${currentMinute}`);
        
        // Calculate how far in the past the booking is (in hours)
        let hoursPast = 0;
        let isInPast = false;
        
        if (bookingDate < currentDate) {
          // If booking date is before current date, it's in the past
          // Calculate rough number of days and convert to hours
          const days = now.diff(startDateTime, 'days').days;
          hoursPast = days * 24;
          isInPast = true;
        } else if (bookingDate === currentDate) {
          // If same date, compare time
          const bookingTimeMinutes = bookingHour * 60 + bookingMinute;
          const currentTimeMinutes = currentHour * 60 + currentMinute;
          
          if (bookingTimeMinutes < currentTimeMinutes) {
            // Convert minutes difference to hours
            hoursPast = (currentTimeMinutes - bookingTimeMinutes) / 60;
            isInPast = true;
          }
        }
        
        console.log(`Booking ${bookingId} start time is ${isInPast ? hoursPast.toFixed(2) + ' hours in past' : 'in future'}`);
        
        // If scheduled start time is in the past (at least 1 hour past to avoid edge cases)
        if (isInPast && hoursPast > 1) {
          console.log(`Case 1: Booking ${bookingId} start time is ${hoursPast.toFixed(2)} hours in the past`);
          
          // Process in an async function to avoid blocking
          (async () => {
            // Update booking status
            await db.ref(`jobs/${bookingId}`).update({
              status: 'expired',
              auto_cancelled_at: now.toISO(),
              cancellation_reason: 'Scheduled start time has passed'
            });
            
            // Issue refund to user
            const refundSuccess = await processRefund(bookingId, booking.user_id);
            
            // Notify user
            if (refundSuccess) {
              await sendUserNotification(
                booking.user_id,
                'Booking Automatically Cancelled',
                `Your booking has been cancelled as the scheduled start time has passed without being accepted. A refund has been issued to your wallet.`,
                { bookingId, type: 'booking_auto_cancelled' }
              );
            }
            
            pastBookingsCount++;
          })();
        } else if (isInPast) {
          console.log(`Booking ${bookingId} is less than 1 hour past its start time (${hoursPast.toFixed(2)} hours), giving some leeway`);
        } else {
          console.log(`Booking ${bookingId} start time is in the future, not cancelling`);
        }
      }
    });
    
    console.log(`Processed ${pastBookingsCount} past scheduled bookings`);
  } catch (error) {
    console.error('Error checking past scheduled bookings:', error);
  }
}

// Run all checks at once
async function runSystemChecks() {
  const now = getMalaysiaTime();
  console.log(`Starting system automation checks at ${now.toFormat('yyyy-MM-dd HH:mm:ss')} (Malaysia Time)...`);
  
  try {
    await checkExpiredBookingRequests();
    await checkPastScheduledBookings();
    await checkPastBookings();
    
    console.log('System checks completed successfully');
  } catch (error) {
    console.error('Error during system checks:', error);
  }
}

// Set up periodic checks
const checkIntervalMs = CHECK_INTERVAL_MINUTES * 60 * 1000;
setInterval(runSystemChecks, checkIntervalMs);

// Run checks when the server starts
setTimeout(runSystemChecks, 5000); // Wait 5 seconds after startup

// API endpoint for status check
router.get('/status', (req, res) => {
  const now = getMalaysiaTime();
  res.json({
    status: 'running',
    nextCheckIn: `${CHECK_INTERVAL_MINUTES} minutes`,
    expirySettings: {
      bookingExpiryHours: BOOKING_EXPIRY_HOURS,
      jobAutoCompleteHours: JOB_AUTO_COMPLETE_HOURS
    },
    timestamp: now.toISO(),
    malaysiaTime: now.toFormat('yyyy-MM-dd HH:mm:ss')
  });
});

// API endpoint to manually trigger checks
router.post('/run-checks', async (req, res) => {
  try {
    console.log('Manual system checks triggered');
    
    // Run all checks
    await runSystemChecks();
    
    const now = getMalaysiaTime();
    res.status(200).json({
      success: true,
      message: 'System checks completed successfully',
      timestamp: now,
      malaysiaTime: now.toFormat('yyyy-MM-dd HH:mm:ss')
    });
  } catch (error) {
    console.error('Error running manual checks:', error);
    res.status(500).json({
      success: false,
      error: 'Error running system checks',
      message: error.message
    });
  }
});

// Export the router
module.exports = router;
