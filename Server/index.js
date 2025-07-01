const express = require('express');
const cors = require('cors');
const admin = require('firebase-admin');
require('dotenv').config();

// Use environment variable for Firebase credentials if available
let serviceAccount;
if (process.env.FIREBASE_SERVICE_ACCOUNT) {
  serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
} else {
  serviceAccount = require('./serviceAccountKey.json');
}

// Initialize Firebase Admin SDK only once for all services
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: process.env.FIREBASE_DATABASE_URL || '',
  storageBucket: process.env.FIREBASE_STORAGE_BUCKET || ''
});

// Initialize Express app
const app = express();
app.use(cors());
app.use(express.json());

// Import routers from each service
const userRouter = require('./backend/User_backend');
const handymanRouter = require('./backend/Handyman_Backend');
const notificationUserRouter = require('./backend/notification_user');
const notificationHandymanRouter = require('./backend/notification_handyman');
const systemAutoRouter = require('./system_auto'); // Add this line

// Root endpoint
app.get('/', (req, res) => {
  res.status(200).json({ 
    status: 'online',
    message: 'HandyGo API Server',
    timestamp: new Date(),
    services: [
      'User API',
      'Handyman API',
      'User Notifications',
      'Handyman Notifications',
      'System Automation' // Add this line
    ]
  });
});

// Mount routers at appropriate paths
app.use('/api/user', userRouter);
app.use('/api/handyman', handymanRouter);
app.use('/api/notifications/user', notificationUserRouter);
app.use('/api/notifications/handyman', notificationHandymanRouter);
app.use('/api/system', systemAutoRouter); // Add this line

// Error handling middleware
app.use((err, req, res, next) => {
  console.error('Unhandled error:', err);
  res.status(500).json({
    error: 'Internal Server Error',
    message: err.message || 'An unexpected error occurred'
  });
});

// Start server
const PORT = process.env.PORT || 5000;
app.listen(PORT, () => {
  console.log(`Unified server is running on http://localhost:${PORT}`);
  console.log('Available endpoints:');
  console.log('- User API: /api/user/*');
  console.log('- Handyman API: /api/handyman/*');
  console.log('- User Notifications: /api/notifications/user/*');
  console.log('- Handyman Notifications: /api/notifications/handyman/*');
});
