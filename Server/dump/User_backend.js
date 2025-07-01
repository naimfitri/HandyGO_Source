// Import required modules
const express = require('express');
const admin = require('firebase-admin');
const cors = require('cors');
const bcrypt = require('bcrypt'); // For hashing passwords
const { v4: uuidv4 } = require('uuid');
const stripe = require('stripe')(''); // Replace with your Stripe secret key
const axios = require('axios');
const multer = require('multer');
const path = require('path');
const fs = require('fs');

require('dotenv').config();

// Initialize Realtime Database instead of Firestore
const db = admin.database();

// Initialize Express Router instead of app
const router = express.Router();
router.use(cors());
router.use(express.json()); // Replaces body-parser for parsing JSON requests

// Middleware to verify Firebase Authentication token
const verifyAuthToken = async (req, res, next) => {
  const token = req.headers.authorization?.split('Bearer ')[1];

  if (!token) {
    return res.status(401).json({ message: 'No token provided' });
  }

  try {
    const decodedToken = await admin.auth().verifyIdToken(token);
    req.user = decodedToken; // Attach user info to the request object
    next(); // Continue to the next middleware/route handler
  } catch (error) {
    console.error('Error verifying token:', error.message);
    res.status(403).json({ message: 'Invalid or expired token' });
  }
};

// Define API Endpoints

/**
 * @route POST /register
 * @desc Register a new user
 * @access Public
 */
router.post('/register', async (req, res) => {
  const { name, email, phone, password } = req.body;

  if (!name || !email || !phone || !password) {
    return res.status(400).json({ message: 'All fields (name, email, phone, password) are required.' });
  }

  try {
    // Check if the user already exists
    const usersRef = db.ref('users');
    const snapshot = await usersRef.orderByChild('email').equalTo(email).once('value');
    
    if (snapshot.exists()) {
      return res.status(400).json({ message: 'User with this email already exists.' });
    }

    // Hash the password
    const hashedPassword = await bcrypt.hash(password, 10);

    // Create user in Realtime Database
    const newUserRef = usersRef.push();
    await newUserRef.set({
      id: newUserRef.key,
      name,
      email,
      phone,
      password: hashedPassword,
      createdAt: admin.database.ServerValue.TIMESTAMP
    });

    res.status(200).json({ message: 'User registered successfully!' });
  } catch (error) {
    console.error('Error registering user:', error.message);
    res.status(500).json({ message: 'Internal Server Error' });
  }
});

/**
 * @route POST /login
 * @desc Login a user
 * @access Public
 */
router.post('/login', async (req, res) => {
  const { email, password } = req.body;

  if (!email || !password) {
    return res.status(400).json({ message: 'Email and password are required.' });
  }

  try {
    // Use Realtime Database instead of Firestore
    const usersRef = db.ref('users');
    const snapshot = await usersRef.orderByChild('email').equalTo(email).once('value');
    
    if (!snapshot.exists()) {
      return res.status(401).json({ message: 'Invalid email or password.' });
    }

    // Get the first user with matching email
    let userData = null;
    let userId = null;
    snapshot.forEach((childSnapshot) => {
      userData = childSnapshot.val();
      userId = childSnapshot.key;
      // We only need the first matching user
      return true;
    });

    const isPasswordValid = await bcrypt.compare(password, userData.password);
    if (!isPasswordValid) {
      return res.status(401).json({ message: 'Invalid email or password.' });
    }

    // Issue a Firebase Auth token to use in subsequent requests
    // Note: For this to work properly, the user should also exist in Firebase Auth
    // Consider using Firebase Auth createUser for registration as well
    try {
      const token = await admin.auth().createCustomToken(userId);
      
      res.status(200).json({
        message: 'Login successful!',
        token,
        user: {
          id: userId,
          name: userData.name,
          email: userData.email,
        },
      });
    } catch (tokenError) {
      console.error('Error creating custom token:', tokenError);
      // Fall back to a successful login without token if token creation fails
      res.status(200).json({
        message: 'Login successful, but token could not be created',
        user: {
          id: userId,
          name: userData.name,
          email: userData.email,
        },
      });
    }
  } catch (error) {
    console.error('Error logging in user:', error.message);
    res.status(500).json({ message: 'Internal Server Error' });
  }
});

/**
 * @route PUT /profile/:id
 * @desc Update a user's profile
 * @access Private
 */
router.put('/profile/:id', verifyAuthToken, async (req, res) => {
  const { id } = req.params;
  const { name, email, password, phone } = req.body;

  if (!name && !email && !password && !phone) {
    return res.status(400).json({ message: 'At least one field (name, email, or password) is required for update.' });
  }

  if (id !== req.user.uid) {
    return res.status(403).json({ message: 'Forbidden: You can only update your own profile.' });
  }

  try {
    const userRef = db.collection('users').doc(id);
    const userDoc = await userRef.get();

    if (!userDoc.exists()) {
      return res.status(404).json({ message: 'User not found.' });
    }

    const updates = {};
    if (name) updates.name = name;
    if (email) updates.email = email;
    if (phone) updates.phone = phone;
    if (password) updates.password = await bcrypt.hash(password, 10);

    await userRef.update(updates);

    res.status(200).json({ message: 'Profile updated successfully!' });
  } catch (error) {
    console.error('Error updating profile:', error.message);
    res.status(500).json({ message: 'Internal Server Error' });
  }
});

/**
 * @route GET /users
 * @desc Get all registered users
 * @access Private (Admin only)
 */
router.get('/users', verifyAuthToken, async (req, res) => {
  if (req.user.role !== 'admin') {
    return res.status(403).json({ message: 'Forbidden: Admins only' });
  }

  try {
    const usersSnapshot = await db.collection('users').get();
    const users = usersSnapshot.docs.map((doc) => ({
      id: doc.id,
      name: doc.data().name,
      email: doc.data().email,
      createdAt: doc.data().createdAt?.toDate(),
    }));
    res.status(200).json(users);
  } catch (error) {
    console.error('Error fetching users:', error.message);
    res.status(500).json({ message: 'Internal Server Error' });
  }
});

/**
 * @route DELETE /delete/:id
 * @desc Delete a user by ID
 * @access Private
 */
router.delete('/delete/:id', verifyAuthToken, async (req, res) => {
  const { id } = req.params;

  if (id !== req.user.uid) {
    return res.status(403).json({ message: 'Forbidden: You can only delete your own profile.' });
  }

  try {
    const userRef = db.collection('users').doc(id);
    const userDoc = await userRef.get();

    if (!userDoc.exists()) {
      return res.status(404).json({ message: 'User not found.' });
    }

    await userRef.delete();
    res.status(200).json({ message: 'User deleted successfully.' });
  } catch (error) {
    console.error('Error deleting user:', error.message);
    res.status(500).json({ message: 'Internal Server Error' });
  }
});

// Add Booking API
router.post("/add-booking", async (req, res) => {
  try {
    const { name, address, description, date, time } = req.body;

    // Use Realtime Database instead of Firestore
    const bookingsRef = db.ref('bookings');
    const newBookingRef = bookingsRef.push();
    
    await newBookingRef.set({
      id: newBookingRef.key,
      name,
      address,
      description,
      date,
      time,
      createdAt: admin.database.ServerValue.TIMESTAMP
    });

    res.status(200).json({ message: "Booking added successfully!" });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

/**
 * @route GET /handymen
 * @desc Get handymen by expertise and city
 * @access Public
 */
router.get('/handymen', async (req, res) => {
  try {
    const { expertise, city } = req.query;
    
    console.log(`Fetching handymen with expertise: ${expertise}, city: ${city || 'any'}`);
    
    // Reference to handymen in the database
    const handymenRef = db.ref('handymen');
    
    // Always get all handymen since we need to filter by expertise array
    const snapshot = await handymenRef.once('value');
    
    if (!snapshot.exists()) {
      return res.status(200).json([]);
    }
    
    const handymen = snapshot.val();
    let result = [];
    
    // Convert to array and filter by expertise and city
    for (const key in handymen) {
      const handyman = {
        id: key,
        ...handymen[key]
      };
      
      // Check if expertise matches - handle both array and string formats
      let expertiseMatches = true;
      if (expertise) {
        if (Array.isArray(handyman.expertise)) {
          // New format: expertise is an array of strings
          expertiseMatches = handyman.expertise.includes(expertise);
        } else {
          // Old format: expertise is a single string
          expertiseMatches = handyman.expertise === expertise;
        }
      }
      
      // Filter by city if specified
      const cityMatches = !city || handyman.city === city;
      
      // Add to results if both filters match
      if (expertiseMatches && cityMatches) {
        result.push(handyman);
      }
    }
    
    console.log(`Found ${result.length} matching handymen`);
    return res.status(200).json(result);
    
  } catch (error) {
    console.error('Error fetching handymen:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

/**
 * @route POST /save-location
 * @desc Save user location data
 * @access Public (you might want to add authentication here)
 */
router.post('/save-location', async (req, res) => {
  try {
    const { 
      buildingName, 
      unitName, 
      streetName, 
      postalCode, 
      city, 
      country, 
      latitude, 
      longitude, 
      userId,
      timestamp 
    } = req.body;

    if (!userId || !latitude || !longitude) {
      return res.status(400).json({ message: 'User ID, latitude, and longitude are required' });
    }

    // Reference to the locations node under the specific user
    const userLocationsRef = db.ref(`users/${userId}/locations`);
    
    // Create a new location entry
    const newLocationRef = userLocationsRef.push();
    
    await newLocationRef.set({
      id: newLocationRef.key,
      buildingName: buildingName || '',
      unitName: unitName || '',
      streetName: streetName || '',
      postalCode: postalCode || '',
      city: city || '',
      country: country || '',
      latitude,
      longitude,
      createdAt: timestamp || admin.database.ServerValue.TIMESTAMP
    });

    // Also save as the user's primary address if they don't have one yet
    const userRef = db.ref(`users/${userId}`);
    const userSnapshot = await userRef.once('value');
    const userData = userSnapshot.val();
    
    if (!userData || !userData.primaryAddress) {
      await userRef.update({
        primaryAddress: {
          buildingName: buildingName || '',
          unitName: unitName || '',
          streetName: streetName || '',
          postalCode: postalCode || '',
          city: city || '',
          country: country || '',
          latitude,
          longitude,
          updatedAt: admin.database.ServerValue.TIMESTAMP
        }
      });
    }

    res.status(200).json({ 
      message: 'Location saved successfully',
      locationId: newLocationRef.key
    });
  } catch (error) {
    console.error('Error saving location:', error);
    res.status(500).json({ message: 'Internal Server Error' });
  }
});

/**
 * @route GET /handyman-availability/:UserId
 * @desc Get available slots for a handyman for the next 7 days
 * @access Public
 */
router.get('/handyman-availability/:UserId', async (req, res) => {
  try {
    const { UserId } = req.params;
    
    if (!UserId) {
      return res.status(400).json({ message: 'Handyman ID is required' });
    }

    console.log(`Fetching availability for handyman: ${UserId}`);

    // Get today's date and the next 7 days
    const today = new Date();
    today.setHours(0, 0, 0, 0); // Start of today
    
    // Create an object to store the availability for the next 7 days
    const availability = {};
    
    // Generate dates for the next 7 days and initialize each with available slots
    for (let i = 0; i < 7; i++) {
      const currentDate = new Date(today);
      currentDate.setDate(today.getDate() + i);
      
      // Format as YYYY-MM-DD
      const dateString = currentDate.toISOString().split('T')[0];
      
      // Initialize all slots as available for this date
      availability[dateString] = {
        "1": true, // Slot 1: 8AM-12PM (true means available)
        "2": true, // Slot 2: 1PM-5PM
        "3": true  // Slot 3: 6PM-10PM
      };
    }

    // Check handyman's schedule (days they work)
    const handymanRef = db.ref(`handymen/${UserId}`);
    const handymanSnapshot = await handymanRef.once('value');
    const handymanData = handymanSnapshot.val();
    
    if (!handymanData) {
      return res.status(404).json({ message: 'Handyman not found' });
    }

    // Process the schedule (only make slots available on days they work)
    if (handymanData.schedule) {
      // Get the days of the week the handyman is available
      const availableDays = Object.keys(handymanData.schedule)
        .filter(day => handymanData.schedule[day] === 'available');
      
      console.log(`Handyman works on: ${availableDays.join(', ')}`);
      
      // Make slots unavailable on days the handyman doesn't work
      Object.keys(availability).forEach(dateString => {
        const date = new Date(dateString);
        const dayOfWeek = getDayName(date.getDay());
        
        if (!availableDays.includes(dayOfWeek)) {
          // Set all slots to unavailable for this day
          availability[dateString] = {
            "1": false,
            "2": false,
            "3": false
          };
        }
      });
    }

    // Get all jobs assigned to this handyman
    const jobsRef = db.ref('jobs');
    const snapshot = await jobsRef.orderByChild('assigned_to').equalTo(UserId).once('value');
    
    if (snapshot.exists()) {
      snapshot.forEach((childSnapshot) => {
        const job = childSnapshot.val();
        
        // Parse the date from the starttimestamp (assuming ISO format)
        const startDate = new Date(job.starttimestamp);
        const jobDate = startDate.toISOString().split('T')[0]; // YYYY-MM-DD
        
        // Get slot ID from slot name
        const slotName = job.assigned_slot; // "Slot 1", "Slot 2", or "Slot 3" 
        const slotId = slotName.split(' ')[1]; // Extract just the number
        
        // If this date is within our 7-day window and the slot exists
        if (availability[jobDate]) {
          // Mark this slot as unavailable
          availability[jobDate][slotId] = false;
          console.log(`Marked ${jobDate}, ${slotName} as unavailable due to existing job`);
        }
      });
    }

    console.log('Final availability:', availability);

    // Only include dates that have at least one available slot
    const availableDates = {};
    let hasAvailableSlots = false;
    
    Object.keys(availability).forEach(date => {
      const dateSlots = availability[date];
      // Check if at least one slot is available for this date
      const hasAvailableSlot = Object.values(dateSlots).some(isAvailable => isAvailable);
      
      if (hasAvailableSlot) {
        availableDates[date] = dateSlots;
        hasAvailableSlots = true;
      }
    });

    res.status(200).json({
      UserId,
      availability: availableDates,
      hasAvailableSlots
    });
    
  } catch (error) {
    console.error('Error fetching handyman availability:', error);
    res.status(500).json({ message: 'Internal Server Error', error: error.message });
  }
});

/**
 * @route GET /handyman-slots
 * @desc Get all booked slots for a specific handyman
 * @access Public
 */
router.get('/handyman-slots', async (req, res) => {
  try {
    const UserId = req.query.UserId;
    
    if (!UserId) {
      return res.status(400).json({ message: 'Handyman ID parameter is required' });
    }
    
    console.log(`Fetching booked slots for handyman: ${UserId}`);
    
    // Define time slots with their start times (24-hour format)
    const slotStartTimes = {
      '1': 8,  // 8:00 AM
      '2': 13, // 1:00 PM
      '3': 18  // 6:00 PM
    };
    
    // Get current date and time
    const now = new Date();
    const currentHour = now.getHours();
    const today = now.toISOString().split('T')[0]; // YYYY-MM-DD
    
    // Get jobs from database
    const jobsRef = db.ref('jobs');
    const snapshot = await jobsRef.orderByChild('assigned_to').equalTo(UserId).once('value');
    
    // Create a map of dates to arrays of booked slot IDs
    const bookedSlots = {};
    
    // Mark today's passed or current slots as booked
    // For today, mark slots that have already started as booked
    const todaySlots = [];
    
    for (const [slotId, startHour] of Object.entries(slotStartTimes)) {
      if (currentHour >= startHour) {
        todaySlots.push(slotId);
      }
    }
    
    if (todaySlots.length > 0) {
      bookedSlots[today] = todaySlots;
    }
    
    // Add booked slots from jobs
    if (snapshot.exists()) {
      snapshot.forEach((childSnapshot) => {
        const job = childSnapshot.val();
        
        // Extract date from the job's starttimestamp
        const startDate = new Date(job.starttimestamp);
        const dateString = startDate.toISOString().split('T')[0]; // YYYY-MM-DD
        
        // Only process current or future dates (not past dates)
        const jobDate = new Date(dateString);
        const nowDate = new Date(today);
        
        // Skip if the job date is in the past
        if (jobDate < nowDate) {
          console.log(`Skipping past job date: ${dateString}`);
          return;
        }
        
        // Extract slot ID from slot name
        const slotName = job.assigned_slot; // "Slot 1", "Slot 2", etc.
        const slotId = slotName.split(' ')[1]; // "1", "2", etc.
        
        // Initialize array for this date if needed
        if (!bookedSlots[dateString]) {
          bookedSlots[dateString] = [];
        }
        
        // Add this slot ID to the booked slots for this date if not already there
        if (!bookedSlots[dateString].includes(slotId)) {
          bookedSlots[dateString].push(slotId);
        }
      });
      
      console.log(`Found booked slots:`, bookedSlots);
    } else {
      console.log(`No jobs found for handyman ${UserId}`);
    }
    
    res.status(200).json({ bookedSlots });
  } catch (error) {
    console.error('Error fetching handyman slots:', error);
    res.status(500).json({ message: 'Internal Server Error' });
  }
});

/**
 * @route GET /user/:userId
 * @desc Get user information by ID
 * @access Public
 */
router.get('/user/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    
    if (!userId) {
      return res.status(400).json({ message: 'User ID is required' });
    }
    
    // Get user data from Firebase
    const userRef = db.ref(`users/${userId}`);
    const snapshot = await userRef.once('value');
    
    if (!snapshot.exists()) {
      return res.status(404).json({ message: 'User not found' });
    }
    
    const userData = snapshot.val();
    
    // If the user has a primaryAddress, include it directly
    // Otherwise, try to get the first location from locations object
    if (!userData.primaryAddress && userData.locations) {
      const locationKeys = Object.keys(userData.locations);
      if (locationKeys.length > 0) {
        userData.primaryAddress = userData.locations[locationKeys[0]];
      }
    }
    
    res.status(200).json(userData);
  } catch (error) {
    console.error('Error fetching user data:', error);
    res.status(500).json({ message: 'Internal Server Error' });
  }
});

/**
 * @route GET /handyman/:UserId
 * @desc Get handyman details by ID
 * @access Public
 */
router.get('/handyman/:UserId', async (req, res) => {
  try {
    const { UserId } = req.params;
    
    if (!UserId) {
      return res.status(400).json({ message: 'Handyman ID is required' });
    }
    
    // Get handyman reference
    const handymanRef = db.ref(`handymen/${UserId}`);
    const snapshot = await handymanRef.once('value');
    
    if (!snapshot.exists()) {
      return res.status(404).json({ message: 'Handyman not found' });
    }
    
    const handymanData = snapshot.val();
    
    // Remove sensitive info like password before sending response
    const { password, ...safeData } = handymanData;
    
    res.status(200).json(safeData);
  } catch (error) {
    console.error('Error fetching handyman details:', error);
    res.status(500).json({ message: 'Internal Server Error' });
  }
});

/**
 * @route POST /create-booking
 * @desc Create a new booking
 * @access Public
 */
router.post('/create-booking', async (req, res) => {
  try {
    const {
      user_id,
      handyman_id,
      slot_date,
      slot_number,
      description,
      address,
      latitude,
      longitude,
      category,
      start_timestamp,
      end_timestamp
    } = req.body;
    
    // Validate required fields
    if (!user_id || !handyman_id || !slot_date || !slot_number || !description) {
      return res.status(400).json({ message: 'Missing required fields' });
    }
    
    // Generate unique booking ID
    const booking_id = uuidv4();
    
    // Create booking object
    const newBooking = {
      booking_id,
      user_id,
      assigned_to: handyman_id, // Match the field name in your existing jobs
      assigned_slot: slot_number,
      description,
      address: address || 'No address provided',
      latitude: latitude || 0,
      longitude: longitude || 0,
      status: 'Pending', // Set status to Pending as requested
      category,
      starttimestamp: start_timestamp,
      endtimestamp: end_timestamp,
      created_at: new Date().toISOString()
    };
    
    // Save to Firebase
    const bookingRef = db.ref(`jobs/${booking_id}`);
    await bookingRef.set(newBooking);
    
    console.log(`Created booking with ID: ${booking_id}`);
    
    res.status(201).json({
      message: 'Booking created successfully',
      booking_id
    });
  } catch (error) {
    console.error('Error creating booking:', error);
    res.status(500).json({ message: 'Internal Server Error' });
  }
});

/**
 * @route POST /create-booking-with-fee
 * @desc Create a booking and deduct the processing fee
 * @access Private
 */
router.post('/create-booking-with-fee', async (req, res) => {
  try {
    console.log('Received booking request:', JSON.stringify(req.body));
    
    // Extract fields with fallbacks for different naming conventions
    const { 
      userId, 
      user_id,
      UserId, 
      handymanId, // Add support for handymanId (frontend naming)
      category, 
      date, 
      timeSlot, 
      notes, 
      description, // Also accept description field
      processingFee,
      address = null,
      latitude = null,
      longitude = null,
      termsAccepted = false, // Add terms acceptance
      starttimestamp = null, // Allow pre-calculated timestamps
      endtimestamp = null
    } = req.body;
    
    // Use userId or user_id, whichever is available
    const actualUserId = userId || user_id;
    // Use UserId or handymanId, whichever is available
    const actualHandymanId = UserId || handymanId;
    // Use notes or description, whichever is available
    const actualNotes = notes || description || "";
    
    console.log(`Processing booking: User=${actualUserId}, Handyman=${actualHandymanId}, Category=${category}`);
    
    // Validate required fields (now with fallbacks)
    if (!actualUserId || !actualHandymanId || !category || !date || !timeSlot) {
      return res.status(400).json({ 
        message: 'Missing required fields',
        received: {
          userId: actualUserId,
          handymanId: actualHandymanId,
          category,
          date,
          timeSlot
        } 
      });
    }
    
    // Get user reference to check wallet balance
    const userRef = db.ref(`users/${actualUserId}`);
    const userSnapshot = await userRef.once('value');
    
    if (!userSnapshot.exists()) {
      return res.status(404).json({ message: 'User not found' });
    }
    
    // Check if user has enough balance
    const userData = userSnapshot.val();
    const currentWalletBalance = userData.wallet || 0;
    
    if (currentWalletBalance < processingFee) {
      return res.status(400).json({ message: 'Insufficient wallet balance' });
    }
    
    // Get user's address if not provided
    let bookingAddress = address;
    let bookingLatitude = latitude;
    let bookingLongitude = longitude;
    
    if (!bookingAddress && userData.primaryAddress) {
      bookingAddress = formatAddress(userData.primaryAddress);
      
      // Try to get coordinates
      if (userData.primaryAddress.latitude) {
        bookingLatitude = userData.primaryAddress.latitude;
      }
      
      if (userData.primaryAddress.longitude) {
        bookingLongitude = userData.primaryAddress.longitude;
      }
    }
    
    // Generate a unique booking ID
    const bookingId = admin.database().ref().push().key;
    
    // Get time slots for the booking
    let startTime = starttimestamp;
    let endTime = endtimestamp;
    
    if (!startTime || !endTime) {
      switch(timeSlot) {
        case 'Slot 1':
          startTime = `${date.split('T')[0]}T08:00:00.000Z`;
          endTime = `${date.split('T')[0]}T12:00:00.000Z`;
          break;
        case 'Slot 2':
          startTime = `${date.split('T')[0]}T13:00:00.000Z`;
          endTime = `${date.split('T')[0]}T17:00:00.000Z`;
          break;
        case 'Slot 3':
          startTime = `${date.split('T')[0]}T18:00:00.000Z`;
          endTime = `${date.split('T')[0]}T22:00:00.000Z`;
          break;
        default:
          return res.status(400).json({ message: 'Invalid time slot' });
      }
    }
    
    // Get global fare amount
    const fareSnapshot = await db.ref('fare').once('value');
    const fareData = fareSnapshot.val();
    const fareAmount = fareData?.amount || 15; // Default to 15 if not found
    
    // Create booking object to match your structure
    const booking = {
      booking_id: bookingId,
      user_id: actualUserId,
      assigned_to: actualHandymanId,
      assigned_slot: timeSlot,
      category,
      starttimestamp: startTime,
      endtimestamp: endTime,
      created_at: new Date().toISOString(),
      status: "Pending",
      description: actualNotes,
      address: bookingAddress || "Address not provided",
      latitude: bookingLatitude,
      longitude: bookingLongitude,
      hasMaterials: false,
      termsAccepted: termsAccepted
    };
    
    // Store booking in jobs node
    const jobRef = db.ref(`jobs/${bookingId}`);
    await jobRef.set(booking);
    
    // Deduct processing fee from user's wallet
    const newWalletBalance = currentWalletBalance - fareAmount;
    await userRef.update({
      wallet: newWalletBalance
    });
    
    // Record the transaction
    const transactionRef = db.ref('walletTransactions').push();
    await transactionRef.set({
      userId: actualUserId,
      amount: -fareAmount, // Negative to indicate deduction
      timestamp: admin.database.ServerValue.TIMESTAMP,
      transactionType: 'booking-fee',
      bookingId,
      description: `Processing fee for booking ${bookingId}`
    });
    
    // Return success response
    res.status(201).json({
      success: true,
      booking_id: bookingId,
      deducted_amount: fareAmount,
      new_wallet_balance: newWalletBalance
    });
  } catch (error) {
    console.error('Error creating booking with fee:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Submit a rating
router.post('/ratings/submit', async (req, res) => {
  try {
    const { UserId, bookingId, userId, rating, review, userName } = req.body;
    
    if (!UserId || !bookingId || !userId || !rating) {
      return res.status(400).json({ error: 'Missing required fields' });
    }
    
    // Reference to the rating in Firebase
    const ratingRef = admin.database().ref(`ratings/${UserId}/${bookingId}`);
    
    // Get handyman's current rating data
    const handymanRef = admin.database().ref(`handymen/${UserId}`);
    const handymanSnapshot = await handymanRef.once('value');
    const handymanData = handymanSnapshot.val() || {};
    
    // Check if this is an update to an existing rating
    const ratingSnapshot = await ratingRef.once('value');
    const existingRating = ratingSnapshot.exists() ? ratingSnapshot.val() : null;
    
    let currentAverage = handymanData.average_rating || 0;
    let totalRatings = handymanData.total_ratings || 0;
    let newAverage, newTotalRatings;
    
    if (existingRating) {
      // Update existing rating
      const oldRating = existingRating.rating;
      // Remove old rating from average
      const sumWithoutOldRating = currentAverage * totalRatings - oldRating;
      // Add new rating to sum and recalculate average
      newAverage = (sumWithoutOldRating + parseFloat(rating)) / totalRatings;
      newTotalRatings = totalRatings; // Total count remains the same
    } else {
      // New rating
      newTotalRatings = totalRatings + 1;
      newAverage = ((currentAverage * totalRatings) + parseFloat(rating)) / newTotalRatings;
    }
    
    // Round to 2 decimal places
    newAverage = Math.round(newAverage * 100) / 100;
    
    // Save the rating
    await ratingRef.set({
      userId,
      rating: parseFloat(rating),
      review: review || "",
      timestamp: admin.database.ServerValue.TIMESTAMP,
      userName: userName || "Anonymous"
    });
    
    // Update handyman's average rating
    await handymanRef.update({
      average_rating: newAverage,
      total_ratings: newTotalRatings
    });
    
    res.status(200).json({ success: true, message: 'Rating submitted successfully' });
  } catch (error) {
    console.error('Error submitting rating:', error);
    res.status(500).json({ error: 'Error submitting rating' });
  }
});

// Get ratings for a handyman
router.get('/ratings/:UserId', async (req, res) => {
  try {
    const { UserId } = req.params;
    const limit = parseInt(req.query.limit) || 10;
    
    const ratingsRef = admin.database().ref(`ratings/${UserId}`);
    const snapshot = await ratingsRef.limitToLast(limit).once('value');
    
    const ratings = [];
    snapshot.forEach((childSnapshot) => {
      const bookingId = childSnapshot.key;
      const ratingData = childSnapshot.val();
      ratings.push({
        bookingId,
        ...ratingData
      });
    });
    
    // Sort by timestamp descending
    ratings.sort((a, b) => b.timestamp - a.timestamp);
    
    res.status(200).json(ratings);
  } catch (error) {
    console.error('Error getting ratings:', error);
    res.status(500).json({ error: 'Error getting ratings' });
  }
});

// Get rating for a specific booking
router.get('/ratings/:UserId/:bookingId', async (req, res) => {
  console.log(`GET /ratings/${req.params.UserId}/${req.params.bookingId}`);
  
  try {
    const { UserId, bookingId } = req.params;
    
    // Check for required parameters
    if (!UserId || !bookingId) {
      console.log('Missing parameters');
      return res.status(400).json({ error: 'Missing required parameters' });
    }

    // Query the database for this specific rating
    console.log(`Looking up rating at path: ratings/${UserId}/${bookingId}`);
    const ratingRef = admin.database().ref(`ratings/${UserId}/${bookingId}`);
    const snapshot = await ratingRef.once('value');
    
    if (!snapshot.exists()) {
      console.log('Rating not found');
      return res.status(404).json({ error: 'Rating not found' });
    }
    
    const ratingData = snapshot.val();
    console.log('Found rating data:', ratingData);
    res.status(200).json(ratingData);
  } catch (error) {
    console.error('Error retrieving rating:', error);
    res.status(500).json({ error: 'Error retrieving rating data' });
  }
});

// Endpoint to get reviews for a specific handyman
router.get('/handyman-reviews/:UserId', async (req, res) => {
  try {
    const UserId = req.params.UserId;
    
    // Get the ratings from Firebase
    const ratingsRef = admin.database().ref(`ratings/${UserId}`);
    const snapshot = await ratingsRef.once('value');
    const ratingsData = snapshot.val() || {};
    
    // Transform the data into a more usable format for the frontend
    const reviews = Object.entries(ratingsData).map(([bookingId, review]) => ({
      bookingId,
      rating: review.rating,
      review: review.review,
      timestamp: review.timestamp,
      userId: review.userId,
      userName: review.userName || 'Anonymous',
    }));
    
    // Get the average rating for the handyman
    const handymanRef = admin.database().ref(`handymen/${UserId}`);
    const handymanSnapshot = await handymanRef.once('value');
    const handymanData = handymanSnapshot.val() || {};
    
    const averageRating = handymanData.average_rating || 0;
    const totalRatings = handymanData.total_ratings || 0;
    
    return res.status(200).json({
      success: true,
      reviews,
      averageRating,
      totalRatings,
    });
  } catch (error) {
    console.error('Error fetching handyman reviews:', error);
    return res.status(500).json({
      success: false,
      message: 'Failed to fetch handyman reviews',
      error: error.message,
    });
  }
});

// Endpoint to submit a new review
router.post('/submit-review', async (req, res) => {
  try {
    const { UserId, rating, review, userId, userName, bookingId } = req.body;
    
    if (!UserId || !rating || rating < 1 || rating > 5) {
      return res.status(400).json({
        success: false,
        message: 'Invalid review data. UserId and a rating between 1-5 are required.',
      });
    }
    
    const timestamp = Date.now();
    
    // Store the review
    const newReviewRef = admin.database().ref(`ratings/${UserId}`);
    
    // If bookingId provided, use it as the key to prevent duplicate reviews
    // Otherwise, generate a new key
    const reviewKey = bookingId || newReviewRef.push().key;
    
    await newReviewRef.child(reviewKey).set({
      rating,
      review: review || '',
      timestamp,
      userId: userId || 'anonymous',
      userName: userName || 'Anonymous',
    });
    
    // Update the handyman's average rating
    const handymanRef = admin.database().ref(`handymen/${UserId}`);
    const handymanSnapshot = await handymanRef.once('value');
    const handymanData = handymanSnapshot.val() || {};
    
    // Calculate new average
    const currentTotalRatings = handymanData.total_ratings || 0;
    const currentAverageRating = handymanData.average_rating || 0;
    
    // If updating an existing review, first remove its contribution
    if (bookingId) {
      const existingReviewRef = admin.database().ref(`ratings/${UserId}/${bookingId}`);
      const existingReviewSnapshot = await existingReviewRef.once('value');
      const existingReview = existingReviewSnapshot.val();
      
      if (existingReview && existingReview.rating) {
        // This is an update to an existing review, not a new review
        await handymanRef.update({
          average_rating: parseFloat(((currentAverageRating * currentTotalRatings - existingReview.rating + rating) / currentTotalRatings).toFixed(2)),
        });
        
        return res.status(200).json({
          success: true,
          message: 'Review updated successfully',
        });
      }
    }
    
    // This is a new review
    const newTotalRatings = currentTotalRatings + 1;
    const newAverageRating = parseFloat(((currentAverageRating * currentTotalRatings + rating) / newTotalRatings).toFixed(2));
    
    await handymanRef.update({
      total_ratings: newTotalRatings,
      average_rating: newAverageRating,
    });
    
    return res.status(201).json({
      success: true,
      message: 'Review submitted successfully',
    });
  } catch (error) {
    console.error('Error submitting review:', error);
    return res.status(500).json({
      success: false,
      message: 'Failed to submit review',
      error: error.message,
    });
  }
});

// Helper function to format address
function formatAddress(addressObj) {
  const parts = [];
  if (addressObj.unitName) parts.push(addressObj.unitName);
  if (addressObj.buildingName) parts.push(addressObj.buildingName);
  if (addressObj.streetName) parts.push(addressObj.streetName);
  if (addressObj.city) parts.push(addressObj.city);
  if (addressObj.postalCode) parts.push(addressObj.postalCode);
  if (addressObj.country) parts.push(addressObj.country);
  
  return parts.join(', ');
}

/**
 * @route GET /user-bookings/:userId
 * @desc Get all bookings for a user with handyman details
 * @access Private
 */
router.get('/user-bookings/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    
    if (!userId) {
      return res.status(400).json({ message: 'User ID is required' });
    }
    
    // Get all bookings where user_id matches
    const bookingsSnapshot = await db.ref('jobs').orderByChild('user_id').equalTo(userId).once('value');
    
    if (!bookingsSnapshot.exists()) {
      return res.status(200).json({ bookings: [] });
    }
    
    const bookingsData = bookingsSnapshot.val();
    const bookings = [];
    
    // Process each booking and get handyman details
    for (const bookingId in bookingsData) {
      const booking = bookingsData[bookingId];
      
      // If there's a handyman assigned, get their details
      let handymanName = 'Unassigned';
      if (booking.assigned_to) {
        const handymanSnapshot = await db.ref(`handymen/${booking.assigned_to}`).once('value');
        if (handymanSnapshot.exists()) {
          const handymanData = handymanSnapshot.val();
          handymanName = handymanData.name || 'Unknown';
        }
      }
      
      // Add handyman name to booking data
      bookings.push({
        ...booking,
        handyman_name: handymanName
      });
    }
    
    // Sort bookings by date (most recent first)
    bookings.sort((a, b) => {
      const dateA = new Date(a.starttimestamp || 0);
      const dateB = new Date(b.starttimestamp || 0);
      return dateB - dateA;
    });
    
    res.status(200).json({ bookings });
  } catch (error) {
    console.error('Error fetching user bookings:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

/**
 * @route GET /booking/:bookingId
 * @desc Get details for a specific booking
 * @access Public
 */
router.get('/booking/:bookingId', async (req, res) => {
  try {
    const { bookingId } = req.params;
    
    if (!bookingId) {
      return res.status(400).json({ message: 'Booking ID is required' });
    }
    
    // Get booking from Firebase
    const bookingRef = db.ref(`jobs/${bookingId}`);
    const snapshot = await bookingRef.once('value');
    
    if (!snapshot.exists()) {
      return res.status(404).json({ message: 'Booking not found' });
    }
    
    const bookingData = snapshot.val();
    res.status(200).json(bookingData);
  } catch (error) {
    console.error('Error fetching booking:', error);
    res.status(500).json({ message: 'Internal Server Error' });
  }
});

/**
 * @route POST /cancel-booking/:bookingId
 * @desc Cancel a booking and refund the processing fee
 * @access Private
 */
router.post('/cancel-booking/:bookingId', async (req, res) => {
  try {
    const { bookingId } = req.params;
    const { user_id } = req.body;
    
    if (!bookingId || !user_id) {
      return res.status(400).json({ message: 'Booking ID and User ID are required' });
    }
    
    // Get booking reference
    const bookingRef = db.ref(`jobs/${bookingId}`);
    const bookingSnapshot = await bookingRef.once('value');
    
    if (!bookingSnapshot.exists()) {
      return res.status(404).json({ message: 'Booking not found' });
    }
    
    const bookingData = bookingSnapshot.val();
    
    // Check if user is authorized to cancel this booking
    if (bookingData.user_id !== user_id) {
      return res.status(403).json({ message: 'You are not authorized to cancel this booking' });
    }
    
    // Check if booking can be cancelled (not already completed, etc.)
    const currentStatus = bookingData.status.toLowerCase();
    if (currentStatus === 'completed' || currentStatus === 'cancelled') {
      return res.status(400).json({ 
        message: `Cannot cancel a booking that is already ${bookingData.status}` 
      });
    }
    
    // Get the processing fee that was charged
    // First check if booking has a processing_fee field
    let processingFee = 0;
    if (bookingData.processing_fee) {
      processingFee = parseFloat(bookingData.processing_fee);
    } else {
      // If not, get the global fare amount
      const fareSnapshot = await db.ref('fare').once('value');
      const fareData = fareSnapshot.val();
      processingFee = fareData?.amount || 15; // Default to 15 if not found
    }
    
    // Get user reference to refund wallet
    const userRef = db.ref(`users/${user_id}`);
    const userSnapshot = await userRef.once('value');
    
    if (!userSnapshot.exists()) {
      return res.status(404).json({ message: 'User not found' });
    }
    
    // Get current wallet balance
    const userData = userSnapshot.val();
    const currentWalletBalance = userData.wallet || 0;
    
    // Update booking status to cancelled
    await bookingRef.update({
      status: 'cancelled',
      cancelled_at: new Date().toISOString()
    });
    
    // Refund processing fee to user's wallet
    const newWalletBalance = currentWalletBalance + processingFee;
    await userRef.update({
      wallet: newWalletBalance
    });
    
    // Record the refund transaction
    const transactionRef = db.ref('walletTransactions').push();
    await transactionRef.set({
      userId: user_id,
      amount: processingFee, // Positive to indicate refund
      timestamp: admin.database.ServerValue.TIMESTAMP,
      transactionType: 'refund',
      bookingId,
      description: `Refund of processing fee for cancelled booking ${bookingId}`
    });
    
    // Return success response
    res.status(200).json({
      success: true,
      message: 'Booking cancelled and processing fee refunded successfully',
      refund_amount: processingFee,
      new_wallet_balance: newWalletBalance
    });
  } catch (error) {
    console.error('Error cancelling booking:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

/**
 * @route POST /create-payment-intent
 * @desc Create a payment intent for Stripe
 * @access Public
 */
router.post('/create-payment-intent', async (req, res) => {
  try {
    const { amount, currency, userId, userName } = req.body;
    
    // Validate data
    if (!amount || !currency || !userId) {
      return res.status(400).json({ 
        message: 'Missing required parameters' 
      });
    }
    
    // Create the payment intent
    const paymentIntent = await stripe.paymentIntents.create({
      amount,
      currency,
      metadata: { 
        userId,
        userName,
        purpose: 'wallet_topup' 
      },
    });
    
    // Send client secret to client
    res.status(200).json({
      clientSecret: paymentIntent.client_secret,
      paymentIntentId: paymentIntent.id,
    });
  } catch (error) {
    console.error('Error creating payment intent:', error);
    res.status(500).json({ 
      message: 'Error creating payment intent', 
      error: error.message 
    });
  }
});

/**
 * @route POST /confirm-payment
 * @desc Record successful payment and update wallet
 * @access Public
 */
router.post('/confirm-payment', async (req, res) => {
  try {
    const { paymentIntentId, userId, amount, userName } = req.body;
    
    // Verify the payment intent
    const paymentIntent = await stripe.paymentIntents.retrieve(paymentIntentId);
    
    if (paymentIntent.status !== 'succeeded') {
      return res.status(400).json({ message: 'Payment not successful' });
    }
    
    // Get user reference
    const userRef = db.ref(`users/${userId}`);
    const snapshot = await userRef.once('value');
    
    if (!snapshot.exists()) {
      return res.status(404).json({ message: 'User not found' });
    }
    
    // Get current wallet balance
    const userData = snapshot.val();
    const currentBalance = userData.wallet || 0;
    const newBalance = currentBalance + parseFloat(amount);
    
    // Update wallet balance
    await userRef.update({
      wallet: newBalance,
    });
    
    // Add transaction to walletTransactions
    const walletTransactionRef = db.ref('walletTransactions').push();
    await walletTransactionRef.set({
      userId,
      amount: parseFloat(amount),
      paymentIntentId,
      timestamp: admin.database.ServerValue.TIMESTAMP,
      transactionType: 'top-up',
      paymentMethod: 'stripe',
      userName,
    });
    
    res.status(200).json({ 
      success: true,
      newBalance: newBalance
    });
  } catch (error) {
    console.error('Error confirming payment:', error);
    res.status(500).json({
      message: 'Error confirming payment',
      error: error.message,
    });
  }
});

/**
 * @route POST /add-address
 * @desc Add new address for user
 * @access Private
 */
router.post('/add-address', async (req, res) => {
  try {
    const { userId, address } = req.body;
    
    if (!userId || !address) {
      return res.status(400).json({ message: 'Missing required fields' });
    }
    
    // Add timestamp
    address.createdAt = admin.database.ServerValue.TIMESTAMP;
    address.id = admin.database.ref().push().key; // Generate a unique ID
    
    // Add address to user's locations
    const userLocationsRef = db.ref(`users/${userId}/locations/${address.id}`);
    await userLocationsRef.set(address);
    
    // If this is user's first address, make it primary
    const userRef = db.ref(`users/${userId}`);
    const userSnapshot = await userRef.once('value');
    const userData = userSnapshot.val();
    
    if (!userData.primaryAddress) {
      // Set as primary address
      const primaryAddressRef = db.ref(`users/${userId}/primaryAddress`);
      address.updatedAt = admin.database.ServerValue.TIMESTAMP;
      await primaryAddressRef.set(address);
    }
    
    res.status(200).json({ success: true, addressId: address.id });
  } catch (error) {
    console.error('Error adding address:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

/**
 * @route POST /update-address
 * @desc Update an existing address
 * @access Private
 */
router.post('/update-address', async (req, res) => {
  try {
    const { userId, addressId, address } = req.body;
    
    if (!userId || !addressId || !address) {
      return res.status(400).json({ message: 'Missing required fields' });
    }
    
    // Preserve original ID and creation time
    const addressRef = db.ref(`users/${userId}/locations/${addressId}`);
    const snapshot = await addressRef.once('value');
    
    if (!snapshot.exists()) {
      return res.status(404).json({ message: 'Address not found' });
    }
    
    const originalAddress = snapshot.val();
    address.id = addressId;
    address.createdAt = originalAddress.createdAt;
    
    // Update address
    await addressRef.set(address);
    
    // If this is the primary address, also update that reference
    const userRef = db.ref(`users/${userId}`);
    const userSnapshot = await userRef.once('value');
    const userData = userSnapshot.val();
    
    if (userData.primaryAddress && userData.primaryAddress.id === addressId) {
      const primaryAddressRef = db.ref(`users/${userId}/primaryAddress`);
      address.updatedAt = admin.database.ServerValue.TIMESTAMP;
      await primaryAddressRef.set(address);
    }
    
    res.status(200).json({ success: true });
  } catch (error) {
    console.error('Error updating address:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

/**
 * @route POST /set-primary-address
 * @desc Set an address as primary
 * @access Private
 */
router.post('/set-primary-address', async (req, res) => {
  try {
    const { userId, addressId } = req.body;
    
    if (!userId || !addressId) {
      return res.status(400).json({ message: 'Missing required fields' });
    }
    
    // Get address data
    const addressRef = db.ref(`users/${userId}/locations/${addressId}`);
    const snapshot = await addressRef.once('value');
    
    if (!snapshot.exists()) {
      return res.status(404).json({ message: 'Address not found' });
    }
    
    const address = snapshot.val();
    
    // Set as primary address
    const primaryAddressRef = db.ref(`users/${userId}/primaryAddress`);
    address.updatedAt = admin.database.ServerValue.TIMESTAMP;
    await primaryAddressRef.set(address);
    
    res.status(200).json({ success: true });
  } catch (error) {
    console.error('Error setting primary address:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

/**
 * @route DELETE /delete-address
 * @desc Delete an address
 * @access Private
 */
router.delete('/delete-address', async (req, res) => {
  try {
    const { userId, addressId } = req.body;
    
    if (!userId || !addressId) {
      return res.status(400).json({ message: 'Missing required fields' });
    }
    
    // Check if this is the primary address
    const userRef = db.ref(`users/${userId}`);
    const userSnapshot = await userRef.once('value');
    const userData = userSnapshot.val();
    
    // If this is the primary address, clear it
    if (userData.primaryAddress && userData.primaryAddress.id === addressId) {
      const primaryAddressRef = db.ref(`users/${userId}/primaryAddress`);
      await primaryAddressRef.remove();
    }
    
    // Delete the address
    const addressRef = db.ref(`users/${userId}/locations/${addressId}`);
    await addressRef.remove();
    
    // If we just deleted the primary address, set another one as primary if available
    if (userData.primaryAddress && userData.primaryAddress.id === addressId && userData.locations) {
      const locations = userData.locations;
      const locationIds = Object.keys(locations).filter(id => id !== addressId);
      
      if (locationIds.length > 0) {
        // Set the first available location as primary
        const newPrimaryAddressId = locationIds[0];
        const newPrimaryAddress = locations[newPrimaryAddressId];
        newPrimaryAddress.updatedAt = admin.database.ServerValue.TIMESTAMP;
        
        const primaryAddressRef = db.ref(`users/${userId}/primaryAddress`);
        await primaryAddressRef.set(newPrimaryAddress);
      }
    }
    
    res.status(200).json({ success: true });
  } catch (error) {
    console.error('Error deleting address:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

/**
 * @route GET /wallet-transactions/:userId
 * @desc Get wallet transaction history for a user
 * @access Private
 */
router.get('/wallet-transactions/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    const limit = parseInt(req.query.limit) || 50; // Default limit to 50
    
    if (!userId) {
      return res.status(400).json({ message: 'User ID is required' });
    }
    
    // Query wallet transactions from Realtime Database
    // Order by timestamp descending and limit results
    const transactionsSnapshot = await db.ref('walletTransactions')
      .orderByChild('userId')
      .equalTo(userId)
      .limitToLast(limit)
      .once('value');
    
    const transactions = [];
    
    if (transactionsSnapshot.exists()) {
      transactionsSnapshot.forEach((childSnapshot) => {
        const transaction = childSnapshot.val();
        transaction.id = childSnapshot.key;
        
        // Format timestamp if it exists
        if (transaction.timestamp) {
          transaction.formattedDate = new Date(transaction.timestamp).toISOString();
        }
        
        transactions.push(transaction);
      });
      
      // Sort by timestamp descending (newest first)
      transactions.sort((a, b) => {
        return (b.timestamp || 0) - (a.timestamp || 0);
      });
    }
    
    // Get user's current wallet balance
    const userSnapshot = await db.ref(`users/${userId}`).once('value');
    let currentBalance = 0;
    
    if (userSnapshot.exists()) {
      const userData = userSnapshot.val();
      currentBalance = userData.wallet || 0;
    }
    
    res.status(200).json({
      userId,
      currentBalance,
      transactions,
      totalTransactions: transactions.length
    });
  } catch (error) {
    console.error('Error fetching wallet transactions:', error);
    res.status(500).json({ message: 'Internal Server Error' });
  }
});

/**
 * @route GET /user-wallet/:userId
 * @desc Get user's wallet balance
 * @access Private
 */
router.get('/user-wallet/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    
    if (!userId) {
      return res.status(400).json({ message: 'User ID is required' });
    }
    
    // Get user reference
    const userRef = db.ref(`users/${userId}`);
    const snapshot = await userRef.once('value');
    
    if (!snapshot.exists()) {
      return res.status(404).json({ message: 'User not found' });
    }
    
    const userData = snapshot.val();
    const walletBalance = userData.wallet || 0;
    
    res.status(200).json({
      userId,
      walletBalance
    });
  } catch (error) {
    console.error('Error fetching wallet balance:', error);
    res.status(500).json({ message: 'Internal Server Error' });
  }
});

/**
 * @route GET /global-settings/fare
 * @desc Get global fare setting
 * @access Public
 */
router.get('/global-settings/fare', async (req, res) => {
  try {
    const fareSnapshot = await db.ref('fare').once('value');
    const fareData = fareSnapshot.val();
    
    if (!fareData) {
      return res.status(200).json({ amount: 15 }); // Default value
    }
    
    res.status(200).json({
      amount: fareData.amount || 15 // Use the amount from database or default to 15
    });
  } catch (error) {
    console.error('Error fetching fare setting:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

/**
 * @route GET /payment/:bookingId
 * @desc Get payment details for a booking
 * @access Private
 */
router.get('/payment/:bookingId', async (req, res) => {
  try {
    const { bookingId } = req.params;
    
    if (!bookingId) {
      return res.status(400).json({ message: 'Booking ID is required' });
    }
    
    // Get payment reference
    const paymentsRef = db.ref('payments');
    const paymentsSnapshot = await paymentsRef.orderByChild('bookingId').equalTo(bookingId).once('value');
    
    if (!paymentsSnapshot.exists()) {
      return res.status(404).json({ message: 'Payment not found' });
    }
    
    let paymentData = null;
    paymentsSnapshot.forEach((childSnapshot) => {
      paymentData = childSnapshot.val();
      paymentData.id = childSnapshot.key;
    });
    
    res.status(200).json(paymentData);
  } catch (error) {
    console.error('Error fetching payment details:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

router.get('/invoice/:bookingId', async (req, res) => {
  try {
    const { bookingId } = req.params;
    
    if (!bookingId) {
      return res.status(400).json({ message: 'Booking ID is required' });
    }
    
    // Get invoice reference - make sure this matches your Firebase structure
    const invoiceRef = db.ref(`invoices/${bookingId}`);
    const invoiceSnapshot = await invoiceRef.once('value');
    
    if (!invoiceSnapshot.exists()) {
      return res.status(404).json({ message: 'Invoice not found' });
    }
    
    const invoiceData = invoiceSnapshot.val();
    
    // Log the data for debugging
    console.log('Invoice data from Firebase:', invoiceData);
    console.log('Items data:', invoiceData.items);
    
    // Ensure items is a proper object even if empty
    if (!invoiceData.items) {
      invoiceData.items = {};
    }
    
    res.status(200).json(invoiceData);
  } catch (error) {
    console.error('Error fetching invoice details:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

/**
 * @route POST /process-payment
 * @desc Process payment for a completed booking
 * @access Private
 */
router.post('/process-payment', async (req, res) => {
  try {
    const { userId, bookingId, handymanId, amount } = req.body;
    
    // Validate required fields
    if (!userId) {
      return res.status(400).json({ message: 'Missing required field: userId' });
    }

    if (!bookingId) {
      return res.status(400).json({ message: 'Missing required field: bookingId' });
    }

    if (!handymanId) {
      return res.status(400).json({ message: 'Missing required field: handymanId' });
    }

    if (amount === undefined) {
      return res.status(400).json({ message: 'Missing required field: amount' });
    }
    
    // Check if booking exists and is in completed-unpaid status
    const bookingRef = db.ref(`jobs/${bookingId}`);
    const bookingSnapshot = await bookingRef.once('value');
    
    if (!bookingSnapshot.exists()) {
      return res.status(404).json({ message: 'Booking not found' });
    }
    
    const bookingData = bookingSnapshot.val();
    
    if (bookingData.status.toLowerCase() !== 'completed-unpaid') {
      return res.status(400).json({ 
        message: `Cannot process payment for booking with status: ${bookingData.status}` 
      });
    }
    
    // Check if user has enough balance
    const userRef = db.ref(`users/${userId}`);
    const userSnapshot = await userRef.once('value');
    
    if (!userSnapshot.exists()) {
      return res.status(404).json({ message: 'User not found' });
    }
    
    const userData = userSnapshot.val();
    const currentWalletBalance = userData.wallet || 0;
    
    if (currentWalletBalance < amount) {
      return res.status(400).json({ message: 'Insufficient wallet balance' });
    }
    
    // Check if handyman exists
    const handymanRef = db.ref(`handymen/${UserId}`);
    const handymanSnapshot = await handymanRef.once('value');
    
    if (!handymanSnapshot.exists()) {
      return res.status(404).json({ message: 'Handyman not found' });
    }
    
    const handymanData = handymanSnapshot.val();
    const handymanWalletBalance = handymanData.wallet || 0;
    
    // Generate a unique payment ID
    const paymentId = db.ref().push().key;
    
    // Start a transaction
    const updates = {};
    
    // 1. Deduct amount from user's wallet
    const newUserBalance = currentWalletBalance - amount;
    updates[`users/${userId}/wallet`] = newUserBalance;
    
    // 2. Add amount to handyman's wallet
    const newHandymanBalance = handymanWalletBalance + amount;
    updates[`handymen/${handymanId}/wallet`] = newHandymanBalance;
    
    // 3. Update booking status
    updates[`jobs/${bookingId}/status`] = 'Completed-Paid';
    
    // 4. Create payment record
    const payment = {
      paymentId,
      bookingId,
      userId,
      handymanId,
      amount,
      paymentDate: new Date().toISOString(),
      status: 'completed'
    };
    updates[`payments/${paymentId}`] = payment;
    
    // 5. Record transactions
    const userTransactionId = db.ref().push().key;
    const handymanTransactionId = db.ref().push().key;
    
    updates[`walletTransactions/${userTransactionId}`] = {
      userId,
      amount: -amount,
      timestamp: admin.database.ServerValue.TIMESTAMP,
      transactionType: 'payment',
      bookingId,
      description: `Payment for service ${bookingId}`
    };
    
    updates[`walletTransactions/${handymanTransactionId}`] = {
      userId: UserId,
      amount: amount,
      timestamp: admin.database.ServerValue.TIMESTAMP,
      transactionType: 'earnings',
      bookingId,
      description: `Earnings from service ${bookingId}`
    };
    
    // Execute all updates atomically
    await db.ref().update(updates);
    
    res.status(200).json({
      success: true,
      message: 'Payment processed successfully',
      paymentId,
      newBalance: newUserBalance
    });
    
  } catch (error) {
    console.error('Error processing payment:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

/**
 * @route GET /handyman-location/:UserId
 * @desc Get current location of a handyman
 * @access Private
 */
router.get('/handyman-location/:UserId', async (req, res) => {
  try {
    const { UserId } = req.params;
    
    if (!UserId) {
      return res.status(400).json({ message: 'Handyman ID is required' });
    }
    
    // Get handyman location reference
    const locationRef = db.ref(`handymen_locations/${UserId}`);
    const locationSnapshot = await locationRef.once('value');
    
    if (!locationSnapshot.exists()) {
      return res.status(404).json({ message: 'Handyman location not found' });
    }
    
    const locationData = locationSnapshot.val();
    
    // Check if location data is recent (within the last hour)
    const lastUpdated = new Date(locationData.lastUpdated);
    const currentTime = new Date();
    const timeDiff = (currentTime - lastUpdated) / (1000 * 60); // difference in minutes
    
    if (timeDiff > 60) {
      return res.status(200).json({
        message: 'Location data is outdated',
        isOutdated: true,
        lastUpdated: locationData.lastUpdated,
        locationData
      });
    }
    
    res.status(200).json({
      latitude: locationData.latitude,
      longitude: locationData.longitude,
      accuracy: locationData.accuracy,
      lastUpdated: locationData.lastUpdated
    });
  } catch (error) {
    console.error('Error fetching handyman location:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

/**
 * @route GET /users/:userId/address
 * @desc Get user's primary address
 * @access Private
 */
router.get('/users/:userId/address', async (req, res) => {
  try {
    const { userId } = req.params;
    
    console.log(`Fetching address for user ID: ${userId}`);
    
    // Get user reference from Firebase
    const userRef = db.ref(`users/${userId}`);
    const userSnapshot = await userRef.once('value');
    
    if (!userSnapshot.exists()) {
      console.log(`User ${userId} not found`);
      return res.status(404).json({ message: 'User not found' });
    }
    
    const userData = userSnapshot.val();
    
    // Check if user has primaryAddress
    if (userData.primaryAddress) {
      console.log(`Found primary address for user ${userId}`);
      const primaryAddress = userData.primaryAddress;
      
      return res.status(200).json({
        city: primaryAddress.city || '',
        country: primaryAddress.country || '',
        buildingName: primaryAddress.buildingName || '',
        streetName: primaryAddress.streetName || '',
        unitName: primaryAddress.unitName || '',
        postalCode: primaryAddress.postalCode || '',
        latitude: primaryAddress.latitude || 0,
        longitude: primaryAddress.longitude || 0,
        id: primaryAddress.id || ''
      });
    } 
    // If no primary address but has locations, use the most recently created one
    else if (userData.locations && Object.keys(userData.locations).length > 0) {
      console.log(`No primary address found, using most recent location for user ${userId}`);
      
      // Get all locations as array
      const locationsArray = Object.values(userData.locations);
      
      // Sort by creation time (newest first)
      locationsArray.sort((a, b) => b.createdAt - a.createdAt);
      
      // Use the most recent location
      const mostRecentLocation = locationsArray[0];
      
      return res.status(200).json({
        city: mostRecentLocation.city || '',
        country: mostRecentLocation.country || '',
        buildingName: mostRecentLocation.buildingName || '',
        streetName: mostRecentLocation.streetName || '',
        unitName: mostRecentLocation.unitName || '',
        postalCode: mostRecentLocation.postalCode || '',
        latitude: mostRecentLocation.latitude || 0,
        longitude: mostRecentLocation.longitude || 0,
        id: mostRecentLocation.id || ''
      });
    } 
    // No locations at all
    else {
      console.log(`No locations found for user ${userId}`);
      return res.status(200).json({ 
        city: '',
        country: ''
      });
    }
  } catch (error) {
    console.error('Error fetching user address:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

/**
 * @route GET /bookings/completed/:userId
 * @desc Get all completed bookings for a user from jobs table with invoice details
 * @access Private
 */
router.get('/bookings/completed/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    
    console.log(`Fetching completed bookings for user: ${userId}`);
    
    // Reference to the jobs node in the Realtime DB
    const jobsRef = db.ref('jobs');
    
    // Query for completed bookings for this user
    const snapshot = await jobsRef
      .orderByChild('user_id')
      .equalTo(userId)
      .once('value');
    
    if (!snapshot.exists()) {
      console.log(`No jobs found for user: ${userId}`);
      return res.status(200).json([]);
    }
    
    const jobs = snapshot.val();
    const completedBookings = [];
    
    // Get reference to invoices
    const invoicesRef = db.ref('invoices');
    const invoicesSnapshot = await invoicesRef.once('value');
    const invoices = invoicesSnapshot.val() || {};
    
    // Filter completed bookings and convert to array
    for (const key of Object.keys(jobs)) {
      if (jobs[key].status === 'Completed-Paid') {
        // Get invoice for this booking
        const invoice = invoices[key];
        let totalFare = jobs[key].total_fare || 0;
        let itemsTotal = 0; // Initialize itemsTotal here
        
        // If invoice exists, calculate total = fare + sum of all items
        if (invoice) {
          if (invoice.items) {
            // Sum up all item totals
            Object.values(invoice.items).forEach(item => {
              itemsTotal += item.total || 0;
            });
          }
          
          // Calculate total from invoice
          totalFare = (invoice.fare || 0) + itemsTotal;
        }
        
        // Create booking object with all needed fields
        const booking = {
          id: key,
          ...jobs[key],
          // Map fields to match what the Flutter app expects
          name: jobs[key].category || 'Unknown Service',
          date: new Date(jobs[key].starttimestamp).toLocaleDateString(),
          time: new Date(jobs[key].starttimestamp).toLocaleTimeString([], {hour: '2-digit', minute:'2-digit'}),
          fare: invoice?.fare || 0,
          items_total: itemsTotal, // Now itemsTotal is defined
          total_fare: totalFare, // Updated total fare from invoice
        };
        
        completedBookings.push(booking);
      }
    }
    
    // Sort by date (newest first)
    completedBookings.sort((a, b) => {
      // Use starttimestamp for sorting
      const dateA = new Date(a.starttimestamp || 0);
      const dateB = new Date(b.starttimestamp || 0);
      return dateB - dateA;
    });
    
    console.log(`Found ${completedBookings.length} completed bookings for user: ${userId}`);
    res.status(200).json(completedBookings);
    
  } catch (error) {
    console.error('Error fetching completed bookings:', error);
    res.status(500).json({ message: 'Server error', error: error.message });
  }
});

// Helper function to get day name
function getDayName(dayIndex) {
  const days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
  return days[dayIndex];
}

// Configure multer for file uploads
const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 5 * 1024 * 1024, // Limit file size to 5MB
  },
});

// Endpoint for handyman profile image upload
router.post('/api/users/:id/upload-image', upload.single('image'), async (req, res) => {
  try {
    const UserId = req.params.id;
    const file = req.file;
    
    if (!file) {
      return res.status(400).json({
        success: false,
        error: 'No image file provided',
      });
    }
    
    console.log(`⚠️ Processing profile image upload for handyman: ${UserId}`);

    try {
      // Try to upload to Firebase Storage
      const bucket = admin.storage().bucket();
      const fileName = `profile_user/${UserId}.jpg`; // Simplified filename
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
      await admin.database().ref(`users/${UserId}`).update({
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
      await admin.database().ref(`handymen/${UserId}`).update({
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

// Endpoint for user profile image upload
router.post('/api/users/:id/upload-image', upload.single('image'), async (req, res) => {
  try {
    const userId = req.params.id;
    const file = req.file;
    
    if (!file) {
      return res.status(400).json({
        success: false,
        error: 'No image file provided',
      });
    }
    
    console.log(`⚠️ Processing profile image upload for user: ${userId}`);

    try {
      // Try to upload to Firebase Storage
      const bucket = admin.storage().bucket();
      const fileName = `profile_user/${userId}.jpg`; // Simplified filename
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
      
      // Update user record with new image URL in Realtime Database
      await admin.database().ref(`users/${userId}`).update({
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
      const base64Data = file.buffer.toString('base64');
      const dataUrl = `data:${file.mimetype};base64,${base64Data}`;
      
      console.log('⚠️ Using fallback method: Storing image reference in Realtime Database');
      
      // Store a reference to the image in the user profile - FIX: was incorrectly updating handymen
      await admin.database().ref(`users/${userId}`).update({
        profileImage: dataUrl.length > 1000 ? 
          dataUrl.substring(0, 100) + '...[truncated]' : dataUrl,
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

// Add endpoint to get user's profile image
router.get('/user/:userId/profile-image', async (req, res) => {
  try {
    const { userId } = req.params;
    
    if (!userId) {
      return res.status(400).json({ message: 'User ID is required' });
    }
    
    // Get user data from Firebase
    const userRef = db.ref(`users/${userId}`);
    const snapshot = await userRef.once('value');
    
    if (!snapshot.exists()) {
      return res.status(404).json({ message: 'User not found' });
    }
    
    const userData = snapshot.val();
    const imageUrl = userData.profileImage || null;
    
    res.status(200).json({ 
      success: true,
      imageUrl 
    });
  } catch (error) {
    console.error('Error fetching user profile image:', error);
    res.status(500).json({ 
      success: false,
      message: 'Error fetching profile image', 
      error: error.message 
    });
  }
});

// Add a new endpoint to get an image from Firebase Storage for users
router.get('/api/images/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    
    if (!userId) {
      return res.status(400).json({
        success: false,
        error: 'User ID is required'
      });
    }
    
    console.log(`⚠️ Fetching profile image for user: ${userId}`);
    
    try {
      // Get the bucket
      const bucket = admin.storage().bucket();
      const fileName = `profile_user/${userId}.jpg`;
      
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
        expires: Date.now() + 15 * 60 * 1000, // URL valid for 15 minutes
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
        .ref(`users/${userId}`)
        .once('value');
      
      if (!snapshot.exists()) {
        return res.status(404).json({
          success: false,
          error: 'User not found'
        });
      }
      
      const userData = snapshot.val();
      const profileImage = userData.profileImage;
      
      if (!profileImage) {
        return res.status(404).json({
          success: false,
          error: 'No profile image found for this user'
        });
      }
      
      console.log(`✅ Returning profile image from database for user: ${userId}`);
      
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

// Fix the handyman image endpoint 
router.get('/api/images_handyman/:handymanId', async (req, res) => {
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
          error: 'Image not found',
          message: `No image found at ${fileName}`
        });
      }
      
      // Get download URL
      const [url] = await bucket.file(fileName).getSignedUrl({
        action: 'read',
        expires: Date.now() + 15 * 60 * 1000, // URL valid for 15 minutes
      });
      
      console.log(`✅ Generated signed URL for handyman image: ${url}`);
      
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
    console.error('❌ Error fetching handyman image:', error);
    return res.status(500).json({
      success: false,
      error: `Failed to fetch handyman image: ${error.message}`
    });
  }
});

// Add endpoint for handyman profile image upload to ensure consistent file structure
router.post('/api/handymen/:id/upload-image', upload.single('image'), async (req, res) => {
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
      const fileName = `profile_handyman/${handymanId}.jpg`; // Use handyman folder
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
      
      console.log(`✅ Successfully uploaded handyman image to Storage: ${imageUrl}`);
      
      // Update handyman record with new image URL in Realtime Database
      await admin.database().ref(`handymen/${handymanId}`).update({
        profileImage: imageUrl,
        updatedAt: new Date().toISOString()
      });
      
      return res.status(200).json({
        success: true,
        imageUrl: imageUrl,
        message: 'Handyman profile image updated successfully',
      });
    } catch (storageError) {
      console.error('⚠️ Firebase Storage error:', storageError);
      
      // FALLBACK: Generate a data URL and store directly in the database
      const base64Data = file.buffer.toString('base64');
      const dataUrl = `data:${file.mimetype};base64,${base64Data}`;
      
      console.log('⚠️ Using fallback method: Storing handyman image reference in Realtime Database');
      
      // Store a reference to the image in the handyman profile
      await admin.database().ref(`handymen/${handymanId}`).update({
        profileImage: dataUrl.length > 1000 ? 
          dataUrl.substring(0, 100) + '...[truncated]' : dataUrl,
        updatedAt: new Date().toISOString()
      });
      
      return res.status(200).json({
        success: true,
        message: 'Handyman profile image updated using fallback method',
        storageError: storageError.message
      });
    }
  } catch (error) {
    console.error('❌ Handyman image upload error:', error);
    return res.status(500).json({
      success: false,
      error: 'Handyman image upload failed: ' + error.message,
    });
  }
});

// Add endpoint to get handyman profile image
router.get('/handyman/:handymanId/profile-image', async (req, res) => {
  try {
    const { handymanId } = req.params;
    
    if (!handymanId) {
      return res.status(400).json({ message: 'Handyman ID is required' });
    }
    
    // Get handyman data from Firebase
    const handymanRef = db.ref(`handymen/${handymanId}`);
    const snapshot = await handymanRef.once('value');
    
    if (!snapshot.exists()) {
      return res.status(404).json({ message: 'Handyman not found' });
    }
    
    const handymanData = snapshot.val();
    const imageUrl = handymanData.profileImage || null;
    
    res.status(200).json({ 
      success: true,
      imageUrl 
    });
  } catch (error) {
    console.error('Error fetching handyman profile image:', error);
    res.status(500).json({ 
      success: false,
      message: 'Error fetching handyman profile image', 
      error: error.message 
    });
  }
});

// Add a new endpoint to get an image from Firebase Storage for users
router.get('/api/images_handyman/:handymanId', async (req, res) => {
  try {
    const { userId } = req.params;
    
    if (!userId) {
      return res.status(400).json({
        success: false,
        error: 'handyman ID is required'
      });
    }
    
    console.log(`⚠️ Fetching profile image for handyman: ${userId}`);
    
    try {
      // Get the bucket
      const bucket = admin.storage().bucket();
      const fileName = `profile_handyman/${userId}.jpg`;
      
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
        expires: Date.now() + 15 * 60 * 1000, // URL valid for 15 minutes
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
        .ref(`handymen/${userId}`)
        .once('value');
      
      if (!snapshot.exists()) {
        return res.status(404).json({
          success: false,
          error: 'Handyman not found'
        });
      }
      
      const userData = snapshot.val();
      const profileImage = userData.profileImage;
      
      if (!profileImage) {
        return res.status(404).json({
          success: false,
          error: 'No profile image found for this Handyman'
        });
      }
      
      console.log(`✅ Returning profile image from database for Handyman: ${userId}`);
      
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

// Add this new endpoint for getting completed jobs for a specific handyman
router.get('/handyman-jobs/:handymanId', (req, res) => {
  const handymanId = req.params.handymanId;
  console.log(`Fetching jobs for handyman: ${handymanId}`);

  try {
    const jobsRef = db.ref('jobs');

    jobsRef.once('value', (snapshot) => {
      const allJobs = snapshot.val() || {};
      const completedJobs = [];

      Object.entries(allJobs).forEach(([jobId, job]) => {
        if (job.assigned_to === handymanId && job.status === 'Completed-Paid') {
          completedJobs.push({ id: jobId, ...job });
        }
      });

      res.status(200).json({
        jobs: completedJobs,
        count: completedJobs.length
      });
    });
  } catch (error) {
    console.error('Error fetching jobs:', error);
    res.status(500).json({ error: 'Failed to fetch jobs' });
  }
});

// Export the router instead of starting the server
module.exports = router;


