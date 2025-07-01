# HandyGO Project

HandyGO is a comprehensive handyman service platform that connects users with nearby skilled professionals for various household and repair services. The project consists of four main components:

- **HandyGO Mobile App** (for clients and handymen)
- **HandyGO Admin Website**
- **RASA AI Chatbot**
- **Backend Server**

---

## 📱 HandyGO Mobile App

Built with **Flutter**, the HandyGO app has two user types:

- **Client Users** can:
  - Browse and book handymen by category
  - Track booking status (Pending, Accepted, In Progress, Payment)
  - Cancel bookings and receive automatic refunds
  - Chat with the RASA AI chatbot for job classification
  - View booking history

- **Handyman Users** can:
  - Receive and manage job requests
  - Track current and past jobs
  - Update job statuses (Accept, Start, Complete)
  - Get notified when a job is assigned nearby

### Tech Stack
- Flutter
- Firebase Realtime Database
- Firebase Cloud Messaging (FCM)
- RASA integration via REST API

---

## 🖥️ HandyGO Admin Website

Built with **Laravel**, this dashboard allows administrators to:

- Manage users and handymen
- View job activity and booking analytics
- Manually assign or cancel jobs
- Monitor complaints and reviews
- View and manage admin accounts

### Tech Stack
- Laravel (PHP)
- Firebase Realtime Database (via REST API)
- Bootstrap/Tailwind for UI

---

## 🤖 RASA AI Chatbot

The RASA chatbot is used in the mobile app to help users classify their issues and recommend the correct handyman type (e.g., plumber, electrician).

### Features
- Natural language understanding (NLU)
- Intent classification
- Entity recognition
- Custom fallback and form-based flows

### Tech Stack
- RASA Open Source
- Rasa NLU + Core
- Integrated with Flutter app via REST webhook

---

## 🖧 Backend Server

The backend server handles the business logic for:

- Real-time job matching
- Monitoring job statuses and proximity
- Sending FCM notifications to handymen and users
- RASA chatbot middleware integration

### Tech Stack
- Node.js + Express
- Firebase Admin SDK
- FCM (Firebase Cloud Messaging)
- Hosted on VPS or cloud platform (e.g., Render, Heroku, Railway)
