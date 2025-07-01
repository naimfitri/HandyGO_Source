const express = require('express');
const admin = require('firebase-admin');
const bodyParser = require('body-parser');
const cors = require('cors');
const bcrypt = require('bcrypt');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const { DateTime } = require('luxon'); // Add Luxon import for better time handling

require('dotenv').config();

// Initialize Express Router instead of app
const router = express.Router();

// Get database reference from the already initialized Firebase Admin
const db = admin.database();

// Configure multer for file uploads
const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 5 * 1024 * 1024, // Limit file size to 5MB
  },
});

// Handyman registration endpoint
router.post('/register', async (req, res) => {
  try {
    const { uuid, handymanData } = req.body;
    
    if (!uuid || !handymanData) {
      return res.status(400).json({ error: 'Missing required data' });
    }
    
    // Hash the password
    const saltRounds = 10;
    const hashedPassword = await bcrypt.hash(handymanData.password, saltRounds);
    
    // Set the handyman data in Firebase Realtime Database with the UUID as the key
    await admin.database().ref(`handymen/${uuid}`).set({
      name: handymanData.name,
      phone: handymanData.phone,
      email: handymanData.email,
      password: hashedPassword, // Store hashed password instead
      state: handymanData.state,
      city: handymanData.city,
      expertise: handymanData.expertise,
      status: 'pending',  // Default status
      availability: false, // Default availability
      rating: 0.0,        // Default rating
      // Add bank details
      bankName: handymanData.bankName || null,
      accountNumber: handymanData.accountNumber || null,
      // Create wallet structure with proper fields
      wallet: 0
    });
    
    console.log(`Handyman registered: ${uuid}`);
    
    res.status(201).json({ 
      success: true, 
      message: 'Handyman registered successfully. Pending approval.' 
    });
    
  } catch (error) {
    console.error('Error registering handyman:', error);
    res.status(500).json({ error: 'Failed to register handyman: ' + error.message });
  }
});

// Handyman login endpoint
router.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body;
    
    if (!email || !password) {
      return res.status(400).json({ error: 'Email and password are required' });
    }
    
    // Query the handymen in Firebase Realtime Database by email
    const snapshot = await admin.database()
      .ref('handymen')
      .orderByChild('email')
      .equalTo(email)
      .once('value');
    
    // Check if a handyman was found with the provided email
    if (!snapshot.exists()) {
      return res.status(401).json({ error: 'No account found with this email' });
    }
    
    // Get the handyman data
    const handymanData = snapshot.val();
    const handymanId = Object.keys(handymanData)[0]; // Get the UUID/key of the handyman
    const handyman = handymanData[handymanId];
    
    // Compare the provided password with the stored hashed password
    const passwordMatch = await bcrypt.compare(password, handyman.password);
    
    if (!passwordMatch) {
      return res.status(401).json({ error: 'Incorrect password' });
    }
    
    // Return the handyman data (excluding the password)
    const { password: _, ...handymanDataWithoutPassword } = handyman;
    
    res.status(200).json({
      success: true,
      handymanId: handymanId,
      handymanData: handymanDataWithoutPassword
    });
    
  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({ error: 'Login failed: ' + error.message });
  }
});

// Get handyman data endpoint
router.get('/handymen/:handymanId', async (req, res) => {
  try {
    const { handymanId } = req.params;
    
    if (!handymanId) {
      return res.status(400).json({ error: 'Handyman ID is required' });
    }
    
    // Get the handyman data from Firebase Realtime Database
    const snapshot = await admin.database()
      .ref(`handymen/${handymanId}`)
      .once('value');
    
    if (!snapshot.exists()) {
      return res.status(404).json({ error: 'Handyman not found' });
    }
    
    const handymanData = snapshot.val();
    
    // Exclude password from the response for security
    const { password, ...handymanDataWithoutPassword } = handymanData;
    
    res.status(200).json({
      success: true,
      handymanData: handymanDataWithoutPassword
    });
    
  } catch (error) {
    console.error('Error getting handyman data:', error);
    res.status(500).json({ error: 'Failed to get handyman data: ' + error.message });
  }
});

// Get user data endpoint
router.get('/user/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    
    if (!userId) {
      return res.status(400).json({ error: 'user ID is required' });
    }
    
    // Get the handyman data from Firebase Realtime Database
    const snapshot = await admin.database()
      .ref(`users/${userId}`)
      .once('value');
    
    if (!snapshot.exists()) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    const userData = snapshot.val();
    
    // Exclude password from the response for security
    const { password, ...userDataWithoutPassword } = userData;
    
    res.status(200).json({
      success: true,
      userData: userDataWithoutPassword
    });
    
  } catch (error) {
    console.error('Error getting handyman data:', error);
    res.status(500).json({ error: 'Failed to get handyman data: ' + error.message });
  }
});

// Get handyman jobs endpoint
router.get('/handymen/:handymanId/jobs', async (req, res) => {
  try {
    const { handymanId } = req.params;
    
    if (!handymanId) {
      return res.status(400).json({ error: 'Handyman ID is required' });
    }
    
    // Get all jobs from Firebase Realtime Database
    const snapshot = await admin.database()
      .ref('jobs')
      .once('value');
    
    if (!snapshot.exists()) {
      return res.status(200).json({ jobs: [] });
    }
    
    const allJobs = snapshot.val();
    
    // Filter jobs assigned to this handyman
    const handymanJobs = [];
    for (const [jobId, jobData] of Object.entries(allJobs)) {
      if (jobData.assigned_to === handymanId) {
        handymanJobs.push({
          ...jobData,
          booking_id: jobId
        });
      }
    }
    
    res.status(200).json({ 
      success: true,
      jobs: handymanJobs 
    });
    
  } catch (error) {
    console.error('Error getting handyman jobs:', error);
    res.status(500).json({ error: 'Failed to get handyman jobs: ' + error.message });
  }
});

// Update job status endpoint
router.put('/jobs/:bookingId/status', async (req, res) => {
  try {
    const { bookingId } = req.params;
    const { status } = req.body;
    
    if (!bookingId || !status) {
      return res.status(400).json({ error: 'Booking ID and status are required' });
    }
    
    // Update job status in Firebase Realtime Database
    await admin.database()
      .ref(`jobs/${bookingId}/status`)
      .set(status);
    
    res.status(200).json({ 
      success: true,
      message: `Job status updated to ${status}` 
    });
    
  } catch (error) {
    console.error('Error updating job status:', error);
    res.status(500).json({ error: 'Failed to update job status: ' + error.message });
  }
});

// Get handyman job statistics
router.get('/handymen/:handymanId/stats', async (req, res) => {
  try {
    const { handymanId } = req.params;
    console.log(`Getting stats for handyman: ${handymanId}`);
    
    if (!handymanId) {
      return res.status(400).json({ error: 'Handyman ID is required' });
    }
    
    // Initialize values
    let activeBookings = 0;
    let completedJobs = 0;
    let remainingPayout = 0;
    let totalRevenue = 0;
    
    // Get all jobs from Firebase Realtime Database
    const snapshot = await admin.database()
      .ref('jobs')
      .once('value');
    
    if (snapshot.exists()) {
      const allJobs = snapshot.val();
      console.log(`Found ${Object.keys(allJobs).length} total jobs in database`);
      
      // Create a list to hold all job IDs with status "Completed-Unpaid"
      const unpaidJobIds = [];
      
      // Calculate stats from jobs
      for (const [jobId, jobData] of Object.entries(allJobs)) {
        if (jobData.assigned_to === handymanId) {
          console.log(`Processing job ${jobId} with status: ${jobData.status}`);
          
          // Count active bookings - Pending, Accepted, In-Progress
          if (jobData.status === 'Pending' || 
              jobData.status === 'Accepted' || 
              jobData.status === 'In-Progress') {
            activeBookings++;
            console.log(`Active booking: ${jobId}`);
          } 
          
          // Count completed jobs - Completed-Paid and Completed-Unpaid
          else if (jobData.status === 'Completed-Unpaid' || 
                   jobData.status === 'Completed-Paid') {
            completedJobs++;
            console.log(`Completed job: ${jobId}`);
            
            // Track unpaid jobs to calculate remaining payout from invoices
            if (jobData.status === 'Completed-Unpaid') {
              unpaidJobIds.push(jobId);
              console.log(`Added to unpaid job list: ${jobId}`);
            }
          }
        }
      }
      
      // Calculate remaining payout from invoices of unpaid jobs
      if (unpaidJobIds.length > 0) {
        console.log(`Found ${unpaidJobIds.length} unpaid jobs, calculating total from invoices`);
        
        // Check invoices for more accurate fare information
        for (const jobId of unpaidJobIds) {
          try {
            // First try to get invoice data for more accurate pricing
            const invoiceSnapshot = await admin.database()
              .ref(`invoices/${jobId}`)
              .once('value');
              
            if (invoiceSnapshot.exists()) {
              const invoiceData = invoiceSnapshot.val();
              
              // Get the base fare from the invoice
              const baseFare = invoiceData.fare || 0;
              console.log(`Invoice ${jobId}: Base fare = ${baseFare}`);
              
              // Calculate total from all items
              let itemsTotal = 0;
              if (invoiceData.items) {
                Object.values(invoiceData.items).forEach(item => {
                  itemsTotal += item.total || 0;
                });
                console.log(`Invoice ${jobId}: Items total = ${itemsTotal}`);
              }
              
              // Calculate invoice total = base fare + items total
              const invoiceTotal = baseFare + itemsTotal;
              console.log(`Invoice ${jobId}: Total = ${baseFare} + ${itemsTotal} = ${invoiceTotal}`);
              
              // Add to remaining payout
              remainingPayout += invoiceTotal;
              console.log(`Added to remaining payout: ${invoiceTotal}, now at: ${remainingPayout}`);
            } else {
              // Fallback to job's total_fare if no invoice exists
              const jobSnapshot = await admin.database()
                .ref(`jobs/${jobId}`)
                .once('value');
                
              if (jobSnapshot.exists()) {
                const jobData = jobSnapshot.val();
                let jobRevenue = jobData.total_fare || 0;
                if (typeof jobRevenue === 'string') {
                  jobRevenue = parseFloat(jobRevenue) || 0;
                }
                remainingPayout += jobRevenue;
                console.log(`No invoice found. Added job fare to remaining payout: RM${jobRevenue}, now at RM${remainingPayout}`);
              }
            }
          } catch (err) {
            console.error(`Error calculating fare for job ${jobId}:`, err);
          }
        }
      }
    } else {
      console.log('No jobs found in database');
    }
    
    // Get payments data from Firebase Realtime Database for total revenue
    const paymentsSnapshot = await admin.database()
      .ref('payments')
      .orderByChild('handymanId')
      .equalTo(handymanId)
      .once('value');
    
    if (paymentsSnapshot.exists()) {
      const payments = paymentsSnapshot.val();
      console.log(`Found ${Object.keys(payments).length} payments for handyman: ${handymanId}`);
      
      // Calculate total revenue from completed payments
      Object.keys(payments).forEach(paymentId => {
        const payment = payments[paymentId];
        console.log(`Processing payment ${paymentId}:`, payment);
        
        // Check if payment is completed
        if (payment.status === 'completed') {
          const paymentAmount = payment.amount || 0;
          // Convert to number if it's a string
          const numericAmount = typeof paymentAmount === 'string' ? 
            parseFloat(paymentAmount) || 0 : paymentAmount;
          
          totalRevenue += numericAmount;
          console.log(`Added payment to revenue: RM${numericAmount}, new total: RM${totalRevenue}`);
        }
      });
    } else {
      console.log(`No payments found for handyman: ${handymanId}`);
      
      // Fallback approach if no payments are found
      console.log('Trying alternative approach to find payments...');
      const allPaymentsSnapshot = await admin.database()
        .ref('payments')
        .once('value');
        
      if (allPaymentsSnapshot.exists()) {
        const allPayments = allPaymentsSnapshot.val();
        
        // Manually filter payments for this handyman
        Object.keys(allPayments).forEach(paymentId => {
          const payment = allPayments[paymentId];
          if (payment.handymanId === handymanId && payment.status === 'completed') {
            const paymentAmount = payment.amount || 0;
            const numericAmount = typeof paymentAmount === 'string' ? 
              parseFloat(paymentAmount) || 0 : paymentAmount;
            
            totalRevenue += numericAmount;
            console.log(`Added payment to revenue from manual filter: RM${numericAmount}, new total: RM${totalRevenue}`);
          }
        });
      }
    }
    
    // Prepare the response
    const stats = {
      success: true,
      activeBookings,
      completedJobs,
      remainingPayout,
      totalRevenue
    };
    
    console.log(`Stats for handyman ${handymanId}:`, stats);
    
    res.status(200).json(stats);
    
  } catch (error) {
    console.error('Error getting handyman stats:', error);
    res.status(500).json({ 
      success: false,
      error: 'Failed to get handyman stats: ' + error.message,
      activeBookings: 0,
      completedJobs: 0,
      remainingPayout: 0,
      totalRevenue: 0
    });
  }
});

// Add a health check endpoint

// Health check endpoint
router.get('/health', (req, res) => {
  res.status(200).json({ status: 'ok' });
});

// Add these endpoints to your Node.js server

// Get handyman profile
router.get('/handymen/:handymanId/profile', async (req, res) => {
  try {
    const { handymanId } = req.params;
    
    if (!handymanId) {
      return res.status(400).json({ 
        success: false,
        error: 'Handyman ID is required' 
      });
    }
    
    // Get handyman profile from database
    const snapshot = await admin.database()
      .ref(`handymen/${handymanId}`)
      .once('value');
    
    if (!snapshot.exists()) {
      return res.status(404).json({ 
        success: false,
        error: 'Handyman not found' 
      });
    }
    
    // Return profile data
    res.status(200).json({
      success: true,
      profile: snapshot.val()
    });
    
  } catch (error) {
    console.error('Error getting handyman profile:', error);
    res.status(500).json({ 
      success: false,
      error: 'Failed to get handyman profile: ' + error.message 
    });
  }
});

// Update handyman profile
router.put('/handymen/:handymanId/profile', async (req, res) => {
  try {
    const { handymanId } = req.params;
    const { profile } = req.body;
    
    if (!handymanId || !profile) {
      return res.status(400).json({ 
        success: false,
        error: 'Handyman ID and profile data are required' 
      });
    }
    
    // Update handyman profile in database
    await admin.database()
      .ref(`handymen/${handymanId}`)
      .update(profile);
    
    // Return success
    res.status(200).json({
      success: true,
      message: 'Profile updated successfully'
    });
    
  } catch (error) {
    console.error('Error updating handyman profile:', error);
    res.status(500).json({ 
      success: false,
      error: 'Failed to update handyman profile: ' + error.message 
    });
  }
});

// Update handyman profile image
router.put('/handymen/:handymanId/profile-image', async (req, res) => {
  try {
    const { handymanId } = req.params;
    const { imageUrl } = req.body;
    
    if (!handymanId || !imageUrl) {
      return res.status(400).json({ 
        success: false,
        error: 'Handyman ID and image URL are required' 
      });
    }
    
    // Update profile image in database
    await admin.database()
      .ref(`handymen/${handymanId}`)
      .update({
        profileImage: imageUrl
      });
    
    // Return success
    res.status(200).json({
      success: true,
      message: 'Profile image updated successfully'
    });
    
  } catch (error) {
    console.error('Error updating handyman profile image:', error);
    res.status(500).json({ 
      success: false,
      error: 'Failed to update handyman profile image: ' + error.message 
    });
  }
});

// Add a new endpoint to process refund for rejected booking
router.post('/handymen/refund-booking-fee', async (req, res) => {
  try {
    const { bookingId } = req.body;
    
    if (!bookingId) {
      return res.status(400).json({ error: 'Booking ID is required' });
    }
    
    // 1. Get the booking information
    const bookingSnapshot = await admin.database().ref(`jobs/${bookingId}`).once('value');
    const booking = bookingSnapshot.val();
    
    if (!booking) {
      return res.status(404).json({ error: 'Booking not found' });
    }
    
    // 2. Get the user ID associated with this booking
    const userId = booking.user_id;
    
    if (!userId) {
      return res.status(400).json({ error: 'User ID not found in booking' });
    }
    
    // 3. Find the booking fee transaction to determine refund amount
    const transactionsSnapshot = await admin.database()
      .ref('walletTransactions')
      .orderByChild('bookingId')
      .equalTo(bookingId)
      .once('value');
    
    const transactions = transactionsSnapshot.val();
    let refundAmount = 0;
    
    if (transactions) {
      // Find the booking-fee transaction for this booking
      const transactionId = Object.keys(transactions).find(
        key => transactions[key].transactionType === 'booking-fee'
      );
      
      if (transactionId && transactions[transactionId]) {
        // The booking fee is stored as negative, make it positive for refund
        refundAmount = Math.abs(transactions[transactionId].amount);
      } else {
        return res.status(404).json({ error: 'No booking fee transaction found for this booking' });
      }
    } else {
      return res.status(404).json({ error: 'No transactions found for this booking' });
    }
    
    // 4. Update user's wallet balance
    const userRef = admin.database().ref(`users/${userId}`);
    const userSnapshot = await userRef.once('value');
    const user = userSnapshot.val();
    
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    // Calculate new wallet balance
    const currentBalance = user.wallet || 0;
    const newBalance = currentBalance + refundAmount;
    
    // 5. Create transaction record
    const transactionData = {
      userId: userId,
      bookingId: bookingId,
      amount: refundAmount,
      transactionType: 'refund rejected booking',
      description: `Refund of processing fee for rejected booking ${bookingId}`,
      timestamp: Date.now()
    };
    
    // 6. Use a transaction to ensure data consistency
    const transactionRef = admin.database().ref('walletTransactions').push();
    
    // 7. Perform the updates
    await Promise.all([
      userRef.update({ wallet: newBalance }),
      transactionRef.set(transactionData)
    ]);
    
    return res.status(200).json({
      success: true,
      message: 'Refund processed successfully',
      refundAmount: refundAmount,
      userId: userId
    });
    
  } catch (error) {
    console.error('Error processing refund:', error);
    return res.status(500).json({ error: 'Failed to process refund' });
  }
});

// Add new endpoint to update job total fare
router.put('/bookings/:bookingId/fare', async (req, res) => {
  try {
    const { bookingId } = req.params;
    const { totalFare } = req.body;
    
    console.log(`⚠️ Updating total fare for booking: ${bookingId} to ${totalFare}`);
    
    if (!bookingId || totalFare == null) {
      console.log('⚠️ Missing required data');
      return res.status(400).json({ 
        success: false,
        error: 'Booking ID and total fare are required' 
      });
    }
    
    // Check if job exists
    const jobSnapshot = await admin.database()
      .ref(`jobs/${bookingId}`)
      .once('value');
    
    if (!jobSnapshot.exists()) {
      console.log(`❌ Job not found: ${bookingId}`);
      return res.status(404).json({ 
        success: false,
        error: 'Job not found' 
      });
    }
    
    // Update job with total fare
    await admin.database()
      .ref(`jobs/${bookingId}`)
      .update({
        total_fare: totalFare,
        updatedAt: new Date().toISOString()
      });
    
    console.log(`✅ Successfully updated total fare for job ${bookingId} to ${totalFare}`);
    
    res.status(200).json({ 
      success: true,
      message: 'Total fare updated successfully' 
    });
    
  } catch (error) {
    console.error('❌ Error updating total fare:', error);
    res.status(500).json({ 
      success: false,
      error: 'Failed to update total fare: ' + error.message 
    });
  }
});

// Add a new endpoint to get job invoice summary
router.get('/bookings/:bookingId/invoice', async (req, res) => {
  try {
    const { bookingId } = req.params;
    
    console.log(`⚠️ Getting invoice summary for booking: ${bookingId}`);
    
    if (!bookingId) {
      return res.status(400).json({ 
        success: false,
        error: 'Booking ID is required' 
      });
    }
    
    // Get job details
    const jobSnapshot = await admin.database()
      .ref(`jobs/${bookingId}`)
      .once('value');
    
    if (!jobSnapshot.exists()) {
      console.log(`❌ Job not found: ${bookingId}`);
      return res.status(404).json({ 
        success: false,
        error: 'Job not found' 
      });
    }
    
    const jobData = jobSnapshot.val();
    
    // Get invoice items
    const itemsSnapshot = await admin.database()
      .ref(`materials/${bookingId}`)
      .once('value');
    
    if (!itemsSnapshot.exists()) {
      console.log(`No invoice items found for booking: ${bookingId}`);
      return res.status(200).json({ 
        success: true,
        job: jobData,
        items: []
      });
    }
    
    const itemsData = itemsSnapshot.val();
    const items = Object.entries(itemsData).map(([id, data]) => ({
      id,
      ...data,
    }));
    
    res.status(200).json({ 
      success: true,
      job: jobData,
      items: items
    });
    
  } catch (error) {
    console.error('❌ Error getting invoice summary:', error);
    res.status(500).json({ 
      success: false,
      error: 'Failed to get invoice summary: ' + error.message 
    });
  }
});

// Add new endpoints for invoice management
// 1. Create/update the entire invoice

router.put('/bookings/:bookingId/invoice', async (req, res) => {
  try {
    const { bookingId } = req.params;
    const { fare, items } = req.body;
    
    console.log(`⚠️ Creating/updating invoice for booking: ${bookingId}`);
    
    if (!bookingId) {
      return res.status(400).json({ 
        success: false,
        error: 'Booking ID is required' 
      });
    }
    
    // Check if job exists
    const jobSnapshot = await admin.database()
      .ref(`jobs/${bookingId}`)
      .once('value');
    
    if (!jobSnapshot.exists()) {
      console.log(`❌ Job not found: ${bookingId}`);
      return res.status(404).json({ 
        success: false,
        error: 'Job not found' 
      });
    }
    
    // Create invoice data structure
    const baseFare = fare || 0;
    const invoiceData = {
      bookingId,
      baseFare: baseFare,  // Store the base fare separately
      fare: baseFare,      // This will be updated to include items
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    };
    
    // Get the invoice reference - use booking ID as the invoice ID
    const invoiceRef = admin.database().ref(`invoices/${bookingId}`);
    
    // Check if invoice already exists to preserve creation date
    const existingInvoiceSnapshot = await invoiceRef.once('value');
    if (existingInvoiceSnapshot.exists()) {
      const existingInvoice = existingInvoiceSnapshot.val();
      invoiceData.createdAt = existingInvoice.createdAt || invoiceData.createdAt;
    }
    
    // Calculate total including items
    let totalItemsAmount = 0;
    
    // Update the invoice without overwriting items if no new items provided
    if (!items && existingInvoiceSnapshot.exists() && existingInvoiceSnapshot.child('items').exists()) {
      // Calculate sum of existing items
      const existingItems = existingInvoiceSnapshot.child('items').val();
      Object.values(existingItems).forEach(item => {
        totalItemsAmount += item.total || 0;
      });
      
      // Update fare including items
      const totalFare = baseFare + totalItemsAmount;
      
      await invoiceRef.update({
        baseFare: baseFare,
        fare: totalFare,  // Total fare = base fare + items
        updatedAt: new Date().toISOString(),
      });
      
      console.log(`⚠️ Updated invoice with baseFare: ${baseFare}, items total: ${totalItemsAmount}, total fare: ${totalFare}`);
    } else {
      // Set the full invoice object with items if provided
      if (items) {
        invoiceData.items = items;
        
        // Calculate total from provided items
        Object.values(items).forEach(item => {
          totalItemsAmount += item.total || 0;
        });
      }
      
      // Update total fare
      const totalFare = baseFare + totalItemsAmount;
      invoiceData.fare = totalFare;
      
      await invoiceRef.set(invoiceData);
      console.log(`⚠️ Created new invoice with baseFare: ${baseFare}, items total: ${totalItemsAmount}, total fare: ${totalFare}`);
    }
    
    // Update the job with invoice reference and total_fare
    await admin.database()
      .ref(`jobs/${bookingId}`)
      .update({
        hasInvoice: true,
        total_fare: invoiceData.fare,  // Use the calculated total fare
        updatedAt: new Date().toISOString()
      });
    
    console.log(`✅ Successfully created/updated invoice for job ${bookingId} with total fare: ${invoiceData.fare}`);
    
    res.status(200).json({ 
      success: true,
      invoiceId: bookingId,
      totalFare: invoiceData.fare,
      message: 'Invoice created/updated successfully' 
    });
    
  } catch (error) {
    console.error('❌ Error creating/updating invoice:', error);
    res.status(500).json({ 
      success: false,
      error: 'Failed to create/update invoice: ' + error.message 
    });
  }
});

// 2. Get invoice for a booking
router.get('/bookings/:bookingId/invoice', async (req, res) => {
  try {
    const { bookingId } = req.params;
    
    console.log(`⚠️ Getting invoice for booking: ${bookingId}`);
    
    if (!bookingId) {
      return res.status(400).json({ 
        success: false,
        error: 'Booking ID is required' 
      });
    }
    
    // Check if invoice exists
    const invoiceSnapshot = await admin.database()
      .ref(`invoices/${bookingId}`)
      .once('value');
    
    if (!invoiceSnapshot.exists()) {
      console.log(`❌ Invoice not found for booking: ${bookingId}`);
      return res.status(404).json({ 
        success: false,
        error: 'Invoice not found' 
      });
    }
    
    const invoiceData = invoiceSnapshot.val();
    
    res.status(200).json({ 
      success: true,
      invoice: invoiceData
    });
    
  } catch (error) {
    console.error('❌ Error getting invoice:', error);
    res.status(500).json({ 
      success: false,
      error: 'Failed to get invoice: ' + error.message 
    });
  }
});

// 3. Add an invoice item
router.post('/bookings/:bookingId/invoice/items', async (req, res) => {
  try {
    const { bookingId } = req.params;
    const { itemName, quantity, pricePerUnit } = req.body;
    
    console.log(`⚠️ Adding invoice item for booking: ${bookingId}`);
    
    if (!bookingId || !itemName || !quantity || !pricePerUnit) {
      console.log('⚠️ Missing required data');
      return res.status(400).json({ 
        success: false,
        error: 'Booking ID, itemName, quantity and pricePerUnit are required' 
      });
    }
    
    // Check if invoice exists, create if not
    const invoiceRef = admin.database().ref(`invoices/${bookingId}`);
    const invoiceSnapshot = await invoiceRef.once('value');
    
    if (!invoiceSnapshot.exists()) {
      // Create new invoice
      await invoiceRef.set({
        bookingId,
        fare: 0,
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
        items: {}
      });
      
      console.log(`⚠️ Created new invoice for booking: ${bookingId}`);
    }
    
    // Create new item
    const itemRef = admin.database().ref(`invoices/${bookingId}/items`).push();
    const total = quantity * pricePerUnit;
    
    await itemRef.set({
      itemName,
      quantity,
      pricePerUnit,
      total
    });
    
    const itemId = itemRef.key;
    console.log(`✅ Added invoice item with ID: ${itemId}`);
    
    // Calculate total from all items
    const updatedInvoiceSnapshot = await invoiceRef.child('items').once('value');
    let totalFare = 0;
    
    if (updatedInvoiceSnapshot.exists()) {
      const items = updatedInvoiceSnapshot.val();
      Object.values(items).forEach(item => {
        totalFare += item.total || 0;
      });
    }
    
    // Update invoice fare and job total_fare if not manually set
    const jobSnapshot = await admin.database()
      .ref(`jobs/${bookingId}`)
      .once('value');
    
    if (jobSnapshot.exists()) {
      const jobData = jobSnapshot.val();
      
      // Update invoice fare
      await invoiceRef.update({
        fare: jobData.manual_fare ? jobData.total_fare || totalFare : totalFare,
        updatedAt: new Date().toISOString()
      });
      
      // Update job fare if not manually set
      if (!jobData.manual_fare) {
        await admin.database()
          .ref(`jobs/${bookingId}`)
          .update({
            total_fare: totalFare,
            hasInvoice: true,
            updatedAt: new Date().toISOString()
          });
          
        console.log(`✅ Updated job total_fare to: ${totalFare}`);
      }
    }
    
    res.status(201).json({ 
      success: true,
      itemId,
      message: 'Invoice item added successfully',
      totalFare
    });
    
  } catch (error) {
    console.error('❌ Error adding invoice item:', error);
    res.status(500).json({ 
      success: false,
      error: 'Failed to add invoice item: ' + error.message 
    });
  }
});

// 4. Update an invoice item
router.put('/bookings/:bookingId/invoice/items/:itemId', async (req, res) => {
  try {
    const { bookingId, itemId } = req.params;
    const { itemName, quantity, pricePerUnit } = req.body;
    
    console.log(`⚠️ Updating invoice item ${itemId} for booking: ${bookingId}`);
    
    if (!bookingId || !itemId) {
      return res.status(400).json({ 
        success: false,
        error: 'Booking ID and item ID are required' 
      });
    }
    
    // Check if item exists
    const itemRef = admin.database().ref(`invoices/${bookingId}/items/${itemId}`);
    const itemSnapshot = await itemRef.once('value');
    
    if (!itemSnapshot.exists()) {
      console.log(`❌ Invoice item not found: ${itemId}`);
      return res.status(404).json({ 
        success: false,
        error: 'Invoice item not found' 
      });
    }
    
    // Update item data
    const updateData = {};
    
    if (itemName !== undefined) updateData.itemName = itemName;
    if (quantity !== undefined) updateData.quantity = quantity;
    if (pricePerUnit !== undefined) updateData.pricePerUnit = pricePerUnit;
    
    // Calculate total if quantity or price changed
    if (quantity !== undefined || pricePerUnit !== undefined) {
      const currentData = itemSnapshot.val();
      const newQuantity = quantity !== undefined ? quantity : currentData.quantity;
      const newPricePerUnit = pricePerUnit !== undefined ? pricePerUnit : currentData.pricePerUnit;
      updateData.total = newQuantity * newPricePerUnit;
    }
    
    await itemRef.update(updateData);
    console.log(`✅ Updated invoice item: ${itemId}`);
    
    // Recalculate total fare
    const invoiceRef = admin.database().ref(`invoices/${bookingId}`);
    const itemsSnapshot = await invoiceRef.child('items').once('value');
    let totalFare = 0;
    
    if (itemsSnapshot.exists()) {
      const items = itemsSnapshot.val();
      Object.values(items).forEach(item => {
        totalFare += item.total || 0;
      });
    }
    
    // Update invoice fare
    await invoiceRef.update({
      fare: totalFare,
      updatedAt: new Date().toISOString()
    });
    
    // Update job fare if not manually set
    const jobSnapshot = await admin.database()
      .ref(`jobs/${bookingId}`)
      .once('value');
    
    if (jobSnapshot.exists()) {
      const jobData = jobSnapshot.val();
      
      if (!jobData.manual_fare) {
        await admin.database()
          .ref(`jobs/${bookingId}`)
          .update({
            total_fare: totalFare,
            updatedAt: new Date().toISOString()
          });
          
        console.log(`✅ Updated job total_fare to: ${totalFare}`);
      }
    }
    
    res.status(200).json({ 
      success: true,
      message: 'Invoice item updated successfully',
      totalFare
    });
    
  } catch (error) {
    console.error('❌ Error updating invoice item:', error);
    res.status(500).json({ 
      success: false,
      error: 'Failed to update invoice item: ' + error.message 
    });
  }
});

// 5. Delete an invoice item
router.delete('/invoices/:bookingId/items/:itemId', async (req, res) => {
  try {
    const { bookingId, itemId } = req.params;
    
    console.log(`⚠️ Deleting item ${itemId} from invoice for booking: ${bookingId}`);
    
    // Check if invoice exists
    const invoiceRef = admin.database().ref(`invoices/${bookingId}`);
    const invoiceSnapshot = await invoiceRef.once('value');
    
    if (!invoiceSnapshot.exists()) {
      return res.status(404).json({
        success: false,
        error: 'Invoice not found'
      });
    }
    
    const invoiceData = invoiceSnapshot.val();
    const hasManualFare = invoiceData.manualFare === true;
    const baseFare = invoiceData.baseFare || 0;
    
    // Delete the item
    await admin.database()
      .ref(`invoices/${bookingId}/items/${itemId}`)
      .remove();
    
    // If manual fare is set, don't recalculate
    if (hasManualFare) {
      console.log(`⚠️ Keeping manual fare after item deletion: ${invoiceData.fare}`);
      
      res.status(200).json({
        success: true,
        totalFare: invoiceData.fare,
        message: 'Invoice item deleted, manual fare preserved'
      });
      return;
    }
    
    // Otherwise recalculate total fare based on remaining items
    const itemsRef = admin.database().ref(`invoices/${bookingId}/items`);
    const remainingItemsSnapshot = await itemsRef.once('value');
    
    let itemsTotal = 0;
    let hasItems = false;
    
    remainingItemsSnapshot.forEach(childSnapshot => {
      hasItems = true;
      const item = childSnapshot.val();
      itemsTotal += (item.total || 0);
    });
    
    // Calculate total fare = base fare + items total
    const totalFare = baseFare + itemsTotal;
    console.log(`⚠️ Recalculated fare after item deletion: ${baseFare} (base) + ${itemsTotal} (items) = ${totalFare}`);
    
    // Update the invoice's fare
    await invoiceRef.update({
      fare: totalFare,
      updatedAt: new Date().toISOString()
    });
    
    // Also update the job's total_fare
    await admin.database()
      .ref(`jobs/${bookingId}`)
      .update({
        total_fare: totalFare,
        updatedAt: new Date().toISOString()
      });
    
    res.status(200).json({
      success: true,
      totalFare,
      hasItems,
      message: 'Invoice item deleted successfully'
    });
    
  } catch (error) {
    console.error('❌ Error deleting invoice item:', error);
    res.status(500).json({ 
      success: false,
      error: 'Failed to delete invoice item: ' + error.message 
    });
  }
});

// 6. Set manual fare for invoice
router.put('/bookings/:bookingId/invoice/fare', async (req, res) => {
  try {
    const { bookingId } = req.params;
    const { fare, isManual } = req.body;
    
    console.log(`⚠️ Setting invoice fare for booking: ${bookingId} to ${fare} (manual: ${isManual})`);
    
    if (!bookingId || fare === undefined) {
      return res.status(400).json({ 
        success: false,
        error: 'Booking ID and fare are required' 
      });
    }
    
    // Check if invoice exists, create if not
    const invoiceRef = admin.database().ref(`invoices/${bookingId}`);
    const invoiceSnapshot = await invoiceRef.once('value');
    
    if (!invoiceSnapshot.exists()) {
      // Create new invoice
      await invoiceRef.set({
        bookingId: bookingId,
        fare: fare,
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString()
      });
      
      console.log(`⚠️ Created new invoice for booking: ${bookingId}`);
    } else {
      // Update existing invoice
      await invoiceRef.update({
        fare: fare,
        updatedAt: new Date().toISOString()
      });
    }
    
    // Update job with invoice reference and total_fare
    await admin.database()
      .ref(`jobs/${bookingId}`)
      .update({
        hasInvoice: true,
        total_fare: fare,
        manual_fare: isManual === true,
        updatedAt: new Date().toISOString()
      });
    
    console.log(`✅ Successfully set invoice fare for job ${bookingId} to ${fare}`);
    
    res.status(200).json({ 
      success: true,
      message: 'Invoice fare updated successfully' 
    });
    
  } catch (error) {
    console.error('❌ Error setting invoice fare:', error);
    res.status(500).json({ 
      success: false,
      error: 'Failed to set invoice fare: ' + error.message 
    });
  }
});

// 1. Create or get an invoice
router.get('/invoices/:bookingId', async (req, res) => {
  try {
    const { bookingId } = req.params;
    
    console.log(`⚠️ Getting invoice for booking: ${bookingId}`);
    
    if (!bookingId) {
      return res.status(400).json({ 
        success: false,
        error: 'Booking ID is required' 
      });
    }
    
    // Check if invoice exists
    const invoiceRef = admin.database().ref(`invoices/${bookingId}`);
    const invoiceSnapshot = await invoiceRef.once('value');
    
    if (!invoiceSnapshot.exists()) {
      // Invoice doesn't exist yet
      console.log(`⚠️ Invoice not found for booking: ${bookingId}`);
      return res.status(404).json({
        success: false,
        error: 'Invoice not found'
      });
    }
    
    // Return the existing invoice
    const invoiceData = invoiceSnapshot.val();
    
    res.status(200).json({
      success: true,
      invoice: invoiceData
    });
    
  } catch (error) {
    console.error('❌ Error getting invoice:', error);
    res.status(500).json({ 
      success: false,
      error: 'Failed to get invoice: ' + error.message 
    });
  }
});

// 2. Add an item to an invoice
router.post('/invoices/:bookingId/items', async (req, res) => {
  try {
    const { bookingId } = req.params;
    const { itemName, quantity, pricePerUnit, respectManualFare } = req.body;
    
    console.log(`⚠️ Adding item to invoice for booking: ${bookingId} (respectManualFare: ${respectManualFare})`);
    
    if (!bookingId || !itemName || !quantity || !pricePerUnit) {
      return res.status(400).json({ 
        success: false,
        error: 'Booking ID, item name, quantity, and price are required' 
      });
    }
    
    // Calculate total for this item
    const itemTotal = quantity * pricePerUnit;
    
    // Check if invoice exists, create if not
    const invoiceRef = admin.database().ref(`invoices/${bookingId}`);
    const invoiceSnapshot = await invoiceRef.once('value');
    
    // Check if we have a manual fare set
    let hasManualFare = false;
    let baseFare = 0;
    let existingItemsTotal = 0;
    
    if (invoiceSnapshot.exists()) {
      const invoiceData = invoiceSnapshot.val();
      hasManualFare = invoiceData.manualFare === true;
      
      // Get the base fare (service charge without items)
      baseFare = invoiceData.baseFare || invoiceData.fare || 0;
      
      console.log(`⚠️ Invoice has manual fare: ${hasManualFare}, base fare: ${baseFare}`);
      
      // Calculate existing items total if there are items
      if (invoiceData.items) {
        Object.values(invoiceData.items).forEach(item => {
          existingItemsTotal += item.total || 0;
        });
        console.log(`⚠️ Existing items total: ${existingItemsTotal}`);
      }
    }
    
    // Create new invoice if it doesn't exist
    if (!invoiceSnapshot.exists()) {
      // Create new invoice with this as the first item
      await invoiceRef.set({
        bookingId: bookingId,
        baseFare: 0, // No base fare yet
        fare: itemTotal, // Initial fare is just this item's total
        manualFare: false,
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
        items: {}
      });
      
      // Also update the job with the initial total_fare
      await admin.database()
        .ref(`jobs/${bookingId}`)
        .update({
          total_fare: itemTotal,
          hasInvoice: true,
          updatedAt: new Date().toISOString()
        });
        
      console.log(`⚠️ Created new invoice and set job total_fare: ${itemTotal}`);
    }
    
    // Add the new item to the invoice
    const itemsRef = admin.database().ref(`invoices/${bookingId}/items`);
    const newItemRef = itemsRef.push();
    
    await newItemRef.set({
      itemName,
      quantity,
      pricePerUnit,
      total: itemTotal
    });
    
    const itemId = newItemRef.key;
    console.log(`⚠️ Added new item with ID: ${itemId}, total: ${itemTotal}`);
    
    // Only calculate new fare if we should NOT respect manual fare
    // or if there is no manual fare set
    if (!hasManualFare && !respectManualFare) {
      // Recalculate total of all items
      const updatedItemsSnapshot = await itemsRef.once('value');
      let updatedItemsTotal = 0;
      
      updatedItemsSnapshot.forEach(childSnapshot => {
        const item = childSnapshot.val();
        updatedItemsTotal += (item.total || 0);
      });
      
      console.log(`⚠️ Updated items total: ${updatedItemsTotal}`);
      
      // Calculate total fare = base fare + items total
      const totalFare = baseFare + updatedItemsTotal;
      console.log(`⚠️ New total fare: ${baseFare} (base) + ${updatedItemsTotal} (items) = ${totalFare}`);
      
      // Update the invoice's fare
      await invoiceRef.update({
        fare: totalFare,
        updatedAt: new Date().toISOString()
      });
      
      // Update the job's total_fare
      await admin.database()
        .ref(`jobs/${bookingId}`)
        .update({
          total_fare: totalFare,
          hasInvoice: true,
          updatedAt: new Date().toISOString()
        });
      
      console.log(`⚠️ Updated job total_fare to: ${totalFare}`);
      
      res.status(201).json({
        success: true,
        itemId,
        totalFare: totalFare,
        message: 'Invoice item added successfully'
      });
    } else {
      console.log(`⚠️ Keeping manual fare: ${hasManualFare ? "Yes" : "No"}, respectManualFare: ${respectManualFare ? "Yes" : "No"}`);
      
      // If we're respecting manual fare, don't change the total
      const existingFare = invoiceSnapshot.val().fare || 0;
      
      // Make sure the manualFare flag is set
      if (respectManualFare) {
        await invoiceRef.update({
          manualFare: true,
          updatedAt: new Date().toISOString()
        });
        
        // Update the job's manual_fare flag and total_fare as well
        await admin.database()
          .ref(`jobs/${bookingId}`)
          .update({
            manual_fare: true,
            hasInvoice: true,
            updatedAt: new Date().toISOString()
          });
      }
      
      res.status(201).json({
        success: true,
        itemId,
        totalFare: existingFare,
        message: 'Invoice item added successfully (manual fare preserved)'
      });
    }
  } catch (error) {
    console.error('❌ Error adding invoice item:', error);
    res.status(500).json({ 
      success: false,
      error: 'Failed to add invoice item: ' + error.message 
    });
  }
});

// 3. Delete an item from an invoice
router.delete('/invoices/:bookingId/items/:itemId', async (req, res) => {
  try {
    const { bookingId, itemId } = req.params;
    
    console.log(`⚠️ Deleting item ${itemId} from invoice for booking: ${bookingId}`);
    
    if (!bookingId || !itemId) {
      return res.status(400).json({ 
        success: false,
        error: 'Booking ID and item ID are required' 
      });
    }
    
    // Check if invoice and item exist
    const itemRef = admin.database().ref(`invoices/${bookingId}/items/${itemId}`);
    const itemSnapshot = await itemRef.once('value');
    
    if (!itemSnapshot.exists()) {
      return res.status(404).json({
        success: false,
        error: 'Invoice item not found'
      });
    }
    
    // Delete the item
    await itemRef.remove();
    
    // Recalculate total fare based on remaining items
    const invoiceRef = admin.database().ref(`invoices/${bookingId}`);
    const itemsRef = admin.database().ref(`invoices/${bookingId}/items`);
    const updatedItemsSnapshot = await itemsRef.once('value');
    
    let totalFare = 0;
    let hasItems = false;
    
    updatedItemsSnapshot.forEach(childSnapshot => {
      hasItems = true;
      const item = childSnapshot.val();
      totalFare += (item.total || 0);
    });
    
    // Update the invoice's fare
    await invoiceRef.update({
      fare: totalFare,
      updatedAt: new Date().toISOString()
    });
    
    // Also update the job's total_fare for backward compatibility
    await admin.database()
      .ref(`jobs/${bookingId}`)
      .update({
        total_fare: totalFare,
        updatedAt: new Date().toISOString()
      });
    
    res.status(200).json({
      success: true,
      totalFare,
      hasItems,
      message: 'Invoice item deleted successfully'
    });
    
  } catch (error) {
    console.error('❌ Error deleting invoice item:', error);
    res.status(500).json({  
      success: false,
      error: 'Failed to delete invoice item: ' + error.message 
    });
  }
});

// 5. Migration helper - Convert old materials to new invoice structure
router.post('/migrate-invoices', async (req, res) => {
  try {
    console.log('⚠️ Starting migration of materials to invoice structure');
    
    // Get all jobs with materials
    const materialsSnapshot = await admin.database().ref('materials').once('value');
    if (!materialsSnapshot.exists()) {
      return res.status(200).json({
        success: true,
        message: 'No materials to migrate'
      });
    }
    
    const materialsData = materialsSnapshot.val();
    const bookingIds = Object.keys(materialsData);
    const migratedCount = {
      success: 0,
      failed: 0
    };
    const errors = [];
    
    // For each booking with materials, create an invoice
    for (const bookingId of bookingIds) {
      try {
        console.log(`⚠️ Migrating materials for booking: ${bookingId}`);
        
        const jobSnapshot = await admin.database()
          .ref(`jobs/${bookingId}`)
          .once('value');
        
        if (!jobSnapshot.exists()) {
          console.log(`❌ Job not found for booking: ${bookingId}, skipping`);
          migratedCount.failed++;
          errors.push(`Job not found for booking: ${bookingId}`);
          continue;
        }
        
        const jobData = jobSnapshot.val();
        const bookingMaterials = materialsData[bookingId];
        
        // Create new invoice
        const invoiceRef = admin.database().ref(`invoices/${bookingId}`);
        const invoiceData = {
          bookingId: bookingId,
          fare: jobData.total_fare || 0,
          createdAt: new Date().toISOString(),
          updatedAt: new Date().toISOString(),
          items: {}
        };
        
        // Convert old materials to new invoice items format
        if (bookingMaterials && typeof bookingMaterials === 'object') {
          let totalFromItems = 0;
          
          // Convert each material to an invoice item
          for (const materialId in bookingMaterials) {
            if (Object.prototype.hasOwnProperty.call(bookingMaterials, materialId)) {
              const material = bookingMaterials[materialId];
              const total = (material.quantity || 0) * (material.price || 0);
              
              invoiceData.items[materialId] = {
                itemName: material.name || 'Unknown Item',
                quantity: material.quantity || 0,
                pricePerUnit: material.price || 0,
                total: total
              };
              
              totalFromItems += total;
            }
          }
          
          // If no manual fare was set, use the calculated total from items
          if (!jobData.total_fare) {
            invoiceData.fare = totalFromItems;
            
            // Update job's total fare too
            await admin.database()
              .ref(`jobs/${bookingId}`)
              .update({
                total_fare: totalFromItems,
                updatedAt: new Date().toISOString()
              });
          }
        }
        
        // Save the invoice
        await invoiceRef.set(invoiceData);
        migratedCount.success++;
        console.log(`✅ Successfully migrated materials for booking: ${bookingId}`);
      } catch (err) {
        console.error(`❌ Error migrating materials for booking ${bookingId}:`, err);
        migratedCount.failed++;
        errors.push(`${bookingId}: ${err.message}`);
      }
    }
    
    res.status(200).json({
      success: true,
      message: 'Migration completed',
      migrated: migratedCount,
      errors: errors.length > 0 ? errors : null
    });
    
  } catch (error) {
    console.error('❌ Error during migration:', error);
    res.status(500).json({ 
      success: false,
      error: 'Failed to migrate materials to invoices: ' + error.message 
    });
  }
});

// Update the endpoint to handle manual fare updates
router.put('/invoices/:bookingId/fare', async (req, res) => {
  try {
    const { bookingId } = req.params;
    const { fare, isManual } = req.body;
    
    console.log(`⚠️ Setting invoice fare for booking: ${bookingId} to ${fare} (manual: ${isManual})`);
    
    if (!bookingId || fare == null) {
      return res.status(400).json({ 
        success: false,
        error: 'Booking ID and fare are required' 
      });
    }
    
    // Check if invoice exists, create if not
    const invoiceRef = admin.database().ref(`invoices/${bookingId}`);
    const invoiceSnapshot = await invoiceRef.once('value');
    
    if (!invoiceSnapshot.exists()) {
      // Create new invoice with manual fare
      await invoiceRef.set({
        bookingId: bookingId,
        fare: fare,
        manualFare: isManual === true, // Add flag to indicate manual fare
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
        items: {}
      });
      
      console.log(`⚠️ Created new invoice for booking: ${bookingId} with manual fare: ${fare}`);
    } else {
      // Update existing invoice
      await invoiceRef.update({
        fare: fare,
        manualFare: isManual === true, // Add flag to indicate manual fare
        updatedAt: new Date().toISOString()
      });
      
      console.log(`⚠️ Updated invoice for booking: ${bookingId} with manual fare: ${fare}`);
    }
    
    // // Also update the job fare
    // await admin.database()
    //   .ref(`jobs/${bookingId}`)
    //   .update({
    //     total_fare: fare,
    //     manual_fare: isManual === true, // Add flag to indicate manual fare
    //     updatedAt: new Date().toISOString()
    //   });
    
    res.status(200).json({
      success: true,
      message: 'Invoice fare updated successfully'
    });
    
  } catch (error) {
    console.error('❌ Error setting invoice fare:', error);
    res.status(500).json({ 
      success: false,
      error: 'Failed to set invoice fare: ' + error.message 
    });
  }
});

// Also update the delete endpoint to respect manual fare
router.delete('/invoices/:bookingId/items/:itemId', async (req, res) => {
  try {
    const { bookingId, itemId } = req.params;
    
    console.log(`⚠️ Deleting item ${itemId} from invoice for booking: ${bookingId}`);
    
    // Check if invoice has manual fare
    const invoiceRef = admin.database().ref(`invoices/${bookingId}`);
    const invoiceSnapshot = await invoiceRef.once('value');
    
    if (!invoiceSnapshot.exists()) {
      return res.status(404).json({
        success: false,
        error: 'Invoice not found'
      });
    }
    
    const invoiceData = invoiceSnapshot.val();
    const hasManualFare = invoiceData.manualFare === true;
    const existingFare = invoiceData.fare || 0;
    
    // Delete the item
    await admin.database()
      .ref(`invoices/${bookingId}/items/${itemId}`)
      .remove();
    
    // If manual fare is set, don't recalculate
    if (hasManualFare) {
      console.log(`⚠️ Keeping manual fare after item deletion: ${existingFare}`);
      
      res.status(200).json({
        success: true,
        totalFare: existingFare,
        message: 'Invoice item deleted, manual fare preserved'
      });
      return;
    }
    
    // Otherwise recalculate total fare based on remaining items
    const itemsRef = admin.database().ref(`invoices/${bookingId}/items`);
    const remainingItemsSnapshot = await itemsRef.once('value');
    
    let totalFare = 0;
    let hasItems = false;
    
    remainingItemsSnapshot.forEach(childSnapshot => {
      hasItems = true;
      const item = childSnapshot.val();
      totalFare += (item.total || 0);
    });
    
    // Update the invoice's fare
    await invoiceRef.update({
      fare: totalFare,
      updatedAt: new Date().toISOString()
    });
    
    // Also update the job's total_fare
    await admin.database()
      .ref(`jobs/${bookingId}`)
      .update({
        total_fare: totalFare,
        updatedAt: new Date().toISOString()
      });
    
    console.log(`⚠️ Recalculated fare after item deletion: ${totalFare}`);
    
    res.status(200).json({
      success: true,
      totalFare,
      hasItems,
      message: 'Invoice item deleted successfully'
    });
    
  } catch (error) {
    console.error('❌ Error deleting invoice item:', error);
    res.status(500).json({ 
      success: false,
      error: 'Failed to delete invoice item: ' + error.message 
    });
  }
});

// Add this new endpoint for updating handyman location
router.post('/handymen/:handymanId/location', async (req, res) => {
  try {
    const { handymanId } = req.params;
    const { latitude, longitude, timestamp } = req.body;
    
    console.log(`⚠️ Updating location for handyman: ${handymanId} at ${timestamp}`);
    
    if (!handymanId || latitude === undefined || longitude === undefined) {
      return res.status(400).json({ 
        success: false,
        error: 'Handyman ID, latitude, and longitude are required' 
      });
    }
    
    // Convert the timestamp to Kuala Lumpur timezone or use current time
    const malaysiaTime = timestamp 
      ? DateTime.fromISO(timestamp).setZone('Asia/Kuala_Lumpur').toISO()
      : DateTime.now().setZone('Asia/Kuala_Lumpur').toISO();
    
    console.log(`⚠️ Converted timestamp to KL time: ${malaysiaTime}`);
    
    // Store the location in Firebase
    await admin.database().ref(`handymen_locations/${handymanId}`).update({
      latitude: latitude,
      longitude: longitude,
      lastUpdated: malaysiaTime
    });
    
    // Also update the handyman's record to indicate they are available
    await admin.database().ref(`handymen/${handymanId}`).update({
      isAvailable: true, // They're online if they're sending location
      lastSeen: malaysiaTime
    });
    
    console.log(`✅ Successfully updated location for handyman: ${handymanId}`);
    
    res.status(200).json({ 
      success: true,
      message: 'Location updated successfully',
      timestamp: malaysiaTime 
    });
    
  } catch (error) {
    console.error('❌ Error updating handyman location:', error);
    res.status(500).json({ 
      success: false,
      error: 'Failed to update location: ' + error.message 
    });
  }
});

// Add an endpoint to get a handyman's current location
router.get('/handymen/:handymanId/location', async (req, res) => {
  try {
    const { handymanId } = req.params;
    
    console.log(`⚠️ Getting location for handyman: ${handymanId}`);
    
    if (!handymanId) {
      return res.status(400).json({ 
        success: false,
        error: 'Handyman ID is required' 
      });
    }
    
    // Get the location from Firebase
    const snapshot = await admin.database().ref(`handymen_locations/${handymanId}`).once('value');
    
    if (!snapshot.exists()) {
      return res.status(404).json({ 
        success: false,
        error: 'Location not found for this handyman' 
      });
    }
    
    const locationData = snapshot.val();
    
    res.status(200).json({ 
      success: true,
      location: locationData
    });
    
  } catch (error) {
    console.error('❌ Error getting handyman location:', error);
    res.status(500).json({ 
      success: false,
      error: 'Failed to get location: ' + error.message 
    });
  }
});

// Add an endpoint to set availability status
router.post('/handymen/:handymanId/availability', async (req, res) => {
  try {
    const { handymanId } = req.params;
    const { isAvailable } = req.body;
    
    console.log(`⚠️ Setting availability for handyman: ${handymanId} to: ${isAvailable}`);
    
    if (!handymanId || isAvailable === undefined) {
      return res.status(400).json({ 
        success: false,
        error: 'Handyman ID and availability status are required' 
      });
    }
    
    // Update handyman's availability status
    await admin.database().ref(`handymen/${handymanId}`).update({
      isAvailable: isAvailable,
      lastStatusUpdate: new Date().toISOString()
    });
    
    // If going offline, remove from active locations
    if (!isAvailable) {
      await admin.database().ref(`handymen_locations/${handymanId}`).remove();
      console.log(`⚠️ Removed location for handyman: ${handymanId} as they went offline`);
    }
    
    console.log(`✅ Successfully updated availability for handyman: ${handymanId}`);
    
    res.status(200).json({ 
      success: true,
      message: 'Availability updated successfully' 
    });
    
  } catch (error) {
    console.error('❌ Error updating handyman availability:', error);
    res.status(500).json({ 
      success: false,
      error: 'Failed to update availability: ' + error.message 
    });
  }
});

// Get handyman wallet balance and transactions
router.get('/handymen/:handymanId/wallet', async (req, res) => {
  try {
    // Set proper headers
    res.setHeader('Content-Type', 'application/json');
    
    const { handymanId } = req.params;
    
    if (!handymanId) {
      return res.status(400).json({ error: 'Handyman ID is required' });
    }
    
    // Get the handyman data from Firebase Realtime Database
    const handymanSnapshot = await admin.database()
      .ref(`handymen/${handymanId}`)
      .once('value');
    
    if (!handymanSnapshot.exists()) {
      return res.status(404).json({ error: 'Handyman not found' });
    }
    
    const handymanData = handymanSnapshot.val();
    const balance = handymanData.wallet || 0;
    
    // Get wallet transactions for this handyman
    const transactionsSnapshot = await admin.database()
      .ref('walletTransactions')
      .orderByChild('userId')
      .equalTo(handymanId)
      .once('value');
    
    const transactions = [];
    
    if (transactionsSnapshot.exists()) {
      transactionsSnapshot.forEach(childSnapshot => {
        const transaction = childSnapshot.val();
        transaction.id = childSnapshot.key;
        transactions.push(transaction);
      });
      
      // Sort transactions by timestamp (newest first)
      transactions.sort((a, b) => b.timestamp - a.timestamp);
    }
    
    res.status(200).json({
      success: true,
      balance,
      transactions
    });
    
  } catch (error) {
    console.error('Error fetching wallet data:', error);
    res.setHeader('Content-Type', 'application/json');
    res.status(500).json({ 
      success: false,
      error: 'Failed to fetch wallet data: ' + error.message 
    });
  }
});

// Get handyman bank details
router.get('/handymen/:handymanId/bank', async (req, res) => {
  try {
    const { handymanId } = req.params;
    
    if (!handymanId) {
      return res.status(400).json({ error: 'Handyman ID is required' });
    }
    
    // Get the handyman data from Firebase Realtime Database
    const snapshot = await admin.database()
      .ref(`handymen/${handymanId}`)
      .once('value');
    
    if (!snapshot.exists()) {
      return res.status(404).json({ error: 'Handyman not found' });
    }
    
    const handymanData = snapshot.val();
    
    if (!handymanData.bankName || !handymanData.accountNumber) {
      return res.status(404).json({
        success: false,
        error: 'Missing bank details'
      });
    }
    
    // Return bank details
    const bankDetails = {
      bankName: handymanData.bankName,
      accountNumber: handymanData.accountNumber,
    };
    
    res.status(200).json({
      success: true,
      bankDetails
    });
    
  } catch (error) {
    console.error('Error getting bank details:', error);
    res.status(500).json({ error: 'Failed to get bank details: ' + error.message });
  }
});

// Request withdrawal endpoint
router.post('/handymen/:handymanId/withdraw', async (req, res) => {
  try {
    const { handymanId } = req.params;
    const { amount } = req.body;
    
    if (!handymanId) {
      return res.status(400).json({ error: 'Handyman ID is required' });
    }
    
    if (!amount || amount <= 0) {
      return res.status(400).json({ error: 'Valid withdrawal amount is required' });
    }
    
    // Add minimum amount check
    if (amount < 10) {
      return res.status(400).json({ error: 'Minimum withdrawal amount is RM 10' });
    }
    
    // Get current handyman data
    const snapshot = await admin.database()
      .ref(`handymen/${handymanId}`)
      .once('value');
    
    if (!snapshot.exists()) {
      return res.status(404).json({ error: 'Handyman not found' });
    }
    
    const handymanData = snapshot.val();
    
    // Check if bank details are available
    if (!handymanData.bankName || !handymanData.accountNumber) {
      return res.status(400).json({ error: 'Bank details are required before withdrawal' });
    }
    
    // Check if enough balance
    const currentBalance = handymanData.wallet || 0;
    if (currentBalance < amount) {
      return res.status(400).json({ error: 'Insufficient balance for withdrawal' });
    }
    
    // Update wallet balance
    const newBalance = currentBalance - amount;
    await admin.database().ref(`handymen/${handymanId}`).update({
      wallet: newBalance
    });
    
    // Create a new transaction record
    const timestamp = Date.now();
    const transactionRef = admin.database().ref('walletTransactions').push();
    
    await transactionRef.set({
      userId: handymanId,
      amount: amount,
      timestamp: timestamp,
      description: `Withdrawal to ${handymanData.bankName}`,
      transactionType: 'withdrawal',
      transactionStatus: 'pending',
      bankName: handymanData.bankName,
      accountNumber: handymanData.accountNumber
    });
    
    console.log(`Withdrawal requested for handyman: ${handymanId}, amount: ${amount}`);
    
    res.status(200).json({
      success: true,
      message: 'Withdrawal requested successfully',
      withdrawalId: transactionRef.key,
      newBalance: newBalance
    });
    
  } catch (error) {
    console.error('Error requesting withdrawal:', error);
    res.status(500).json({ error: 'Failed to request withdrawal: ' + error.message });
  }
});

// Endpoint for handyman profile image upload
router.post('/handymen/:id/upload-image', upload.single('image'), async (req, res) => {
  try {
    const handymanId = req.params.id;
    const file = req.file;
    
    if (!file) {
      return res.status(400).json({
        success: false,
        error: 'No image file provided',
      });
    }
    
    console.log(`⚠️ Processing profile image upload for handyman: ${handymanId}`);

    try {
      // Try to upload to Firebase Storage
      const bucket = admin.storage().bucket();
      const fileName = `profile_handyman/${handymanId}.jpg`; // Simplified filename
      const fileBuffer = file.buffer;
      
      // Create a file object
      const fileObj = bucket.file(fileName);
      
      // Upload the file buffer directly
      await fileObj.save(fileBuffer, {
        metadata: { contentType: file.mimetype }
      });
      
      // Make the file publicly accessible
      await fileObj.makePublic();
      
      // Get the public URL - adjust to use proper bucket URL format
      const imageUrl = `https://storage.googleapis.com/${bucket.name}/${fileName}`;
      
      console.log(`✅ Successfully uploaded image to Storage: ${imageUrl}`);
      
      // Update handyman record with new image URL in Realtime Database
      await admin.database().ref(`handymen/${handymanId}`).update({
        profileImage: imageUrl,
        updatedAt: new Date().toISOString()
      });
      
      return res.status(200).json({
        success: true,
        imageUrl: imageUrl,
        message: 'Profile image updated successfully',
      });
    } catch (storageError) {
      console.error('⚠️ Firebase Storage error:', storageError);
      
      // FALLBACK: Generate a data URL and store directly in the database
      // Note: This is not recommended for production as it stores the image data directly in the database
      // and should only be used temporarily until the Storage issues are fixed
      const base64Data = file.buffer.toString('base64');
      const dataUrl = `data:${file.mimetype};base64,${base64Data}`;
      
      console.log('⚠️ Using fallback method: Storing image reference in Realtime Database');
      
      // Store a reference to the image in the handyman profile
      await admin.database().ref(`handymen/${handymanId}`).update({
        profileImage: dataUrl.length > 1000 ? 
          dataUrl.substring(0, 100) + '...[truncated]' : dataUrl, // Store a truncated version or URL
        updatedAt: new Date().toISOString()
      });
      
      return res.status(200).json({
        success: true,
        message: 'Profile image updated using fallback method',
        storageError: storageError.message
      });
    }
  } catch (error) {
    console.error('Image upload error:', error);
    return res.status(500).json({
      success: false,
      error: 'Image upload failed: ' + error.message,
    });
  }
});

// Add a new endpoint to get an image from Firebase Storage
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
      // Get the bucket
      const bucket = admin.storage().bucket();
      const fileName = `profile_handyman/${handymanId}.jpg`;
      
      // Check if file exists in storage
      const [exists] = await bucket.file(fileName).exists();
      
      if (!exists) {
        console.log(`❌ Image not found in storage: ${fileName}`);
        return res.status(404).json({
          success: false,
          error: 'Image not found'
        });
      }
      
      // Get download URL
      const [url] = await bucket.file(fileName).getSignedUrl({
        action: 'read',
        expires: Date.now() + 15 * 60 *  1000, // URL valid for 15 minutes
      });
      
      console.log(`✅ Generated signed URL for image: ${url}`);
      
      // Return the URL
      return res.status(200).json({
        success: true,
        imageUrl: url
      });
      
    } catch (storageError) {
      console.error('❌ Firebase Storage error:', storageError);
      
      // Fallback to get image URL from Realtime Database
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

// Add endpoint to get handyman ratings
router.get('/handymen/:handymanId/ratings', async (req, res) => {
  try {
    const { handymanId } = req.params;
    
    console.log(`⚠️ Getting ratings for handyman: ${handymanId}`);
    
    if (!handymanId) {
      return res.status(400).json({ 
        success: false,
        error: 'Handyman ID is required' 
      });
    }
    
    // Get ratings from Firebase Realtime Database
    const ratingsSnapshot = await admin.database()
      .ref(`ratings/${handymanId}`)
      .once('value');
    
    if (!ratingsSnapshot.exists()) {
      return res.status(200).json({ 
        success: true,
        ratings: {},
        averageRating: 0.0
      });
    }
    
    const ratingsData = ratingsSnapshot.val();
    
    // Calculate average rating
    let totalRating = 0;
    let count = 0;
    
    Object.values(ratingsData).forEach(rating => {
      if (rating && rating.rating) {
        totalRating += rating.rating;
        count++;
      }
    });
    
    const averageRating = count > 0 ? totalRating / count : 0.0;
    console.log(`✅ Average rating for handyman ${handymanId}: ${averageRating} from ${count} ratings`);
    
    res.status(200).json({ 
      success: true,
      ratings: ratingsData,
      averageRating
    });
    
  } catch (error) {
    console.error('❌ Error fetching handyman ratings:', error);
    res.status(500).json({ 
      success: false,
      error: 'Failed to get ratings: ' + error.message 
    });
  }
});

// Export the router instead of starting the server
module.exports = router;
