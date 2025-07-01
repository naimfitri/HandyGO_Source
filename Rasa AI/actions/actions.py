import firebase_admin
import uuid
import pytz
import re  # Add this for regex pattern matching
from firebase_admin import credentials
from firebase_admin import db
from datetime import datetime, timedelta
import os
import json
from rasa_sdk.executor import CollectingDispatcher
from rasa_sdk import Action, Tracker
from rasa_sdk.events import SlotSet
from rasa_sdk.events import AllSlotsReset, Restarted
import pandas as pd
from math import radians, cos, sin, asin, sqrt
from . import map_cal as city_map  # This is correct, no change needed
import requests  # Add requests library for HTTP calls

# Define expertise mapping globally so all action classes can access it
expertise_mapping = {
    'report_issue_plumber': 'Plumber',
    'report_issue_electrician': 'Electrician',
    'report_issue_AC': 'AC Repair',
    'report_issue_appliancetech': 'Appliance Repair',
    'report_issue_carpenter': 'Carpenter',
    'report_issue_painter': 'Painter',
    'report_issue_locksmith': 'Locksmith',
    'report_issue_roofer': 'Roofer',
    'report_issue_pest': 'Pest Control',
    'report_issue_tiler': 'Tiler',
    'report_issue_glass': 'Glass & Window',
    'report_issue_gardener': 'Gardener',
    'report_issue_IT': 'IT Support',
    'report_issue_fence': 'Fence & Gate',
    'report_issue_cleaner': 'Cleaner',
}

# Initialize Firebase with credentials based on environment
# This allows both local development (with service account file)
# and production deployment (with environment variables)
try:
    # First try to use environment variables if they exist (for production)
    if os.environ.get('FIREBASE_CONFIG'):
        firebase_config = json.loads(os.environ.get('FIREBASE_CONFIG'))
        cred = credentials.Certificate(firebase_config)
        firebase_database_url = os.environ.get('FIREBASE_DATABASE_URL', 
                               "https://your-default-database-url.firebaseio.com/")
    else:
        # Fall back to local file (for development)
        cred = credentials.Certificate("config/serviceAccountKey.json")
        firebase_database_url = "https://your-default-database-url.firebaseio.com/"
    
    # Initialize the app with a service account
    firebase_admin.initialize_app(cred, {
        'databaseURL': firebase_database_url
    })
    print("Firebase initialization successful")
except Exception as e:
    print(f"Firebase initialization error: {e}")

# Define helper function for intent classification using Rasa HTTP API
def classify_text_with_rasa_server(problem_text):
    """
    Use Rasa's HTTP API to classify text using the currently loaded model
    """
    try:
        response = requests.post(
            "http://localhost:5005/model/parse", 
            json={"text": problem_text}
        )
        parsed_data = response.json()
        return parsed_data['intent']['name'], parsed_data['intent'].get('confidence', 0)
    except Exception as e:
        print(f"Error calling Rasa NLU: {e}")
        return "unknown", 0

class ActionInitializeUserSession(Action):
    def name(self):
        return "action_initialize_user_session"

    def run(self, dispatcher: CollectingDispatcher, tracker: Tracker, domain):
        # Extract user ID and other metadata
        metadata = tracker.latest_message.get("metadata", {})
        user_id = metadata.get("user_id") or tracker.sender_id
        user_name = metadata.get("user_name", "User")

        # Store user information in Firebase
        ref = db.reference(f'/users/{user_id}')
        user_data = ref.get()
        
        if not user_data:
            # If user doesn't exist, create a basic entry
            ref.update({
                'id': user_id,
                'name': user_name,
                'createdAt': int(datetime.now().timestamp() * 1000)
            })
            print(f"Created new user: {user_id} ({user_name})")
        else:
            print(f"User session initialized: {user_id} ({user_name})")

        # No need for a response message as this is just initialization
        return []

class ActionResetConversation(Action):
    def name(self):
        return "action_reset_conversation"

    def run(self, dispatcher, tracker, domain):
        # Reset all slots and restart the conversation
        return [AllSlotsReset(), Restarted()]

class ActionSuggestHandyman(Action):
    def name(self):
        return "action_suggest_handyman"

    def run(self, dispatcher, tracker, domain):
        # Initialize the response variable at the beginning
        response = "I couldn't find any handyman matching your requirements."
        user_problem = tracker.latest_message.get("text", "")
        problem = None
        
        # Get user ID from sender ID
        user_id = tracker.sender_id
        
        # Get user's city from Firebase
        user_ref = db.reference(f'/users/{user_id}')
        user_data = user_ref.get()
        
        user_city = None
        if user_data and 'primaryAddress' in user_data:
            user_city = user_data['primaryAddress'].get('city')
        
        if not user_city:
            # Try to get from slot as fallback
            user_city = tracker.get_slot("location")
            
        # Check which problem the user reported based on the intent
        intent_name = tracker.latest_message['intent'].get('name')
        
        # Map intents to expertise areas
        expertise_mapping = {
            'report_issue_plumber': 'Plumber',
            'report_issue_electrician': 'Electrician',
            'report_issue_AC': 'AC Repair',
            'report_issue_appliancetech': 'Appliance Repair',
            'report_issue_carpenter': 'Carpenter',
            'report_issue_painter': 'Painter',
            'report_issue_locksmith': 'Locksmith',
            'report_issue_roofer': 'Roofer',
            'report_issue_pest': 'Pest Control',
            'report_issue_tiler': 'Tiler',
            'report_issue_glass': 'Glass & Window',
            'report_issue_gardener': 'Gardener',
            'report_issue_IT': 'IT Support',
            'report_issue_fence': 'Fence & Gate',
            'report_issue_cleaner': 'Cleaner',
        }
        
        problem = expertise_mapping.get(intent_name)

        if not problem:
            response = "Sorry, I couldn't identify the problem. Could you please clarify?"
            dispatcher.utter_message(text=response)
            return []

        # Use the helper function to find matching handymen
        city_handymen, other_handymen = get_matching_handymen(problem, user_city)
        
        if not (city_handymen or other_handymen):
            response = "There seems to be an issue fetching handyman data. Please try again later."
            dispatcher.utter_message(text=response)
            return []

        # First check if we have handymen in the user's city
        if city_handymen:
            # Sort handymen by rating in descending order
            city_handymen = sorted(city_handymen, key=lambda x: x.get("average_rating", 0) or x.get("rating", 0), reverse=True)
            
            # Create a text response for platforms that don't support cards
            response = f"Here are some recommended {problem.lower()} experts in {user_city}:\n"
            for h in city_handymen[:3]:  # Show top 3 handymen
                name = h.get('name', 'Unknown')
                rating = h.get('average_rating') or h.get('rating', 0)
                response += f"- {name} (Rating: {rating})\n"
            
            response += "\nWould you like to book any of these experts?"
            
            # Create structured data for card display
            handyman_cards = []
            for h in city_handymen[:3]:
                handyman_cards.append({
                    "name": h.get('name', 'Unknown'),
                    "rating": h.get('average_rating') or h.get('rating', 0),
                    "expertise": h.get('expertise', 'General'),
                    "image_url": h.get('profile_image', "https://xsgames.co/randomusers/avatar.php?g=male"),
                    "id": h.get('id', ''),
                    "city": h.get('city', 'Unknown location')
                })
            
            # Send both text response and custom payload
            dispatcher.utter_message(text=response)
            dispatcher.utter_message(
                json_message={
                    "custom": "handyman_list",
                    "handymen": handyman_cards,
                    "problem_type": problem
                }
            )
        elif other_handymen:
            # No handymen in user's city, but there are handymen elsewhere
            response = f"Looks like there is no {problem.lower()} handyman at your location. Would you like to look outside your location?"
            
            # FIXED: Updated button payload to match exactly what Rasa expects
            dispatcher.utter_message(
                text=response,
                buttons=[
                    {"payload": "/show_other_locations", "title": "Yes, show me other locations"},
                    {"payload": "/cancel_request", "title": "No, cancel my request"}  # FIXED: Changed from "/cancel" to "/cancel_request"
                ]
            )
            # Save the filtered handymen list for later use if user decides to look outside location
            other_handymen = sorted(other_handymen, key=lambda x: x.get("average_rating", 0) or x.get("rating", 0), reverse=True)
            return [
                SlotSet("problem", user_problem),
                SlotSet("handymen_from_other_locations", [h.get('id') for h in other_handymen[:5]])
            ]
        else:
            # No handymen available anywhere
            response = f"Sorry, no {problem.lower()} experts are available at the moment. Would you like to be notified when one becomes available?"
            dispatcher.utter_message(
                text=response,
                buttons=[
                    {"payload": "/notify_when_available", "title": "Yes, notify me"},
                    {"payload": "/cancel", "title": "No, cancel my request"}
                ]
            )
        
        # Add expertise_type to returned slots to be used by ActionShowOtherLocations
        return [SlotSet("problem", user_problem), SlotSet("expertise_type", problem)]

class ActionShowOtherLocations(Action):
    def name(self):
        return "action_show_other_locations"


    def run(self, dispatcher, tracker, domain):
        SlotSet("handyman_name", None),
        SlotSet("handyman_id", None),
        SlotSet("chosen_date", None),
        SlotSet("chosen_slot", None),
        problem = tracker.get_slot("problem")
        # Get the expertise type that was already determined in ActionSuggestHandyman
        required_expertise = tracker.get_slot("expertise_type")
        user_location = tracker.get_slot("user_location") or "Unknown"
        
        print(f"Looking for handymen outside user location: {user_location}")
        
        # Reference to handymen in the database
        ref = db.reference('/handymen')
        handymen_data = ref.get()
        
        if not handymen_data:
            dispatcher.utter_message(text="Sorry, I couldn't access the handyman database right now.")
            return []
        
        # If expertise_type wasn't set for some reason, determine a fallback expertise
        if not required_expertise:
            problem_lower = problem.lower() if problem else ""
            # Use a more limited set of keywords for fallback
            expertise_keywords = {
                "pipe": "Plumber",
                "electric": "Electrician", 
                "ac": "AC Repair",
                "appliance": "Appliance Repair",
                "carpenter": "Carpenter",
                "paint": "Painter"
                
            }
            
            # Try to determine expertise from problem text
            for keyword, expertise in expertise_keywords.items():
                if keyword in problem_lower:
                    required_expertise = expertise
                    break
            
            # Final fallback to Handyman if no match found
            if not required_expertise:
                required_expertise = "Handyman"
        
        print(f"Using expertise: {required_expertise} for searching handymen in other locations")
            
        # Find handymen from other locations who match the expertise
        other_handymen = []
        for h_id, h_data in handymen_data.items():
            # Add handyman ID to the data
            h_data['id'] = h_id
            
            # Check if handyman matches the expertise and is from a different location
            handyman_expertises = h_data.get('expertise', [])
            
            if (h_data.get('city', '').lower() != user_location.lower() and
                isinstance(handyman_expertises, list) and
                any(required_expertise.lower() in exp.lower() for exp in handyman_expertises if isinstance(exp, str))):
                other_handymen.append(h_data)
                
        # Sort handymen by rating
        other_handymen = sorted(
            other_handymen, 
            key=lambda x: x.get("average_rating", 0) or x.get("rating", 0), 
            reverse=True
        )
                
        if other_handymen:
            # First send a text message
            dispatcher.utter_message(text=f"Here are {required_expertise.lower()} experts available in other areas:")
            
            # Create structured data for card display
            handyman_cards = []
            for h in other_handymen[:3]:  # Limit to 3 handymen
                handyman_cards.append({
                    "name": h.get('name', 'Unknown'),
                    "rating": h.get('average_rating') or h.get('rating', 0),
                    "expertise": h.get('expertise', 'General'),
                    "image_url": h.get('profile_image', "https://xsgames.co/randomusers/avatar.php?g=male"),
                    "id": h.get('id', ''),
                    "city": h.get('city', 'Unknown location'),
                    "problem_type": required_expertise
                })
                
            # Important: Send as a separate message with the proper structure
            dispatcher.utter_message(
                json_message={
                    "custom": "handyman_list",
                    "handymen": handyman_cards,
                    "problem_type": required_expertise
                }
            )
            
            # Set slot with handymen IDs from other locations
            handymen_ids = [h['id'] for h in other_handymen]
            
            # Send follow-up message separately with explicit instruction to SELECT the handyman
            dispatcher.utter_message(text="Please select one of these experts to view their availability.")
            
            # Store the expertise type for later use
            return [
                SlotSet("handymen_from_other_locations", handymen_ids),
                SlotSet("expertise_type", required_expertise),
                SlotSet("selection_in_progress", True)  # Add a flag to indicate we're in handyman selection
            ]
        else:
            response = f"I'm sorry, there are no {required_expertise.lower()} specialists available in other areas at the moment."
            dispatcher.utter_message(text=response)
            return []
    
class ActionBookHandyman(Action):
    def name(self):
        return "action_book_handyman"

    def run(self, dispatcher: CollectingDispatcher, tracker: Tracker, domain):
        # First check if we have a handyman ID from previous selections or from entity
        handyman_id = tracker.get_slot("handyman_id")
        handyman_id_entity = next(tracker.get_latest_entity_values("handyman_id"), None)
        
        if handyman_id_entity:
            handyman_id = handyman_id_entity
            
        # Only fall back to handyman_name if ID is not available
        handyman_name = None
        if not handyman_id:
            handyman_name = next(tracker.get_latest_entity_values("handyman_name"), None)
            if not handyman_name:
                # Fall back to getting text if no entity was extracted
                handyman_name = tracker.latest_message.get("text")
            
        print(f"Looking up handyman - ID: {handyman_id}, Name: {handyman_name}")
        
        # Reference to handymen in the database
        ref = db.reference('/handymen')
        handymen_data = ref.get()
        
        if not handymen_data:
            dispatcher.utter_message(text="Sorry, I couldn't access the handyman database right now.")
            return []
            
        # Find the handyman by ID (preferred) or name
        handyman = None
        if handyman_id and handyman_id in handymen_data:
            # Direct lookup by ID is most reliable
            handyman = handymen_data[handyman_id]
            handyman["id"] = handyman_id
            print(f"Found handyman by ID: {handyman.get('name')}")
        elif handyman_name:
            # Fallback to name lookup if ID not available
            for h_id, h_data in handymen_data.items():
                handyman_full_name = h_data.get("name", "").lower()
                if (handyman_name.lower() in handyman_full_name or 
                    any(part in handyman_full_name for part in handyman_name.lower().split())):
                    handyman = h_data
                    handyman["id"] = h_id
                    handyman_id = h_id
                    print(f"Found handyman by name: {handyman_name} → {handyman.get('name')}")
                    break
                
        if handyman:
            # Store handyman selection first
            events = [SlotSet("handyman_name", handyman['name']), 
                     SlotSet("handyman_id", handyman['id'])]
            
            # Always check availability regardless of which handyman was selected
            busy_slots = {}
            
            # Check the handyman's existing jobs to determine availability
            jobs_ref = db.reference('/jobs')
            jobs_data = jobs_ref.get() or {}

            # Define standard time slots
            slots = {
                "Slot 1": ("08:00 AM", "12:00 PM"),
                "Slot 2": ("01:00 PM", "05:00 PM"),
                "Slot 3": ("06:00 PM", "10:00 PM"),
            }

            # Find existing jobs for this handyman
            if jobs_data:
                for job_id, job in jobs_data.items():
                    if job.get("assigned_to") == handyman_id and job.get("status") in ["Pending", "In-Progress"]:
                        try:
                            job_timestamp = job.get("starttimestamp", "")
                            if not job_timestamp:
                                continue
                                
                            # Parse the timestamp properly
                            if "T" in job_timestamp:
                                job_date_str = job_timestamp.split("T")[0]
                                job_date = datetime.strptime(job_date_str, "%Y-%m-%d").date()
                                job_slot = job.get("assigned_slot")
                                
                                if job_date not in busy_slots:
                                    busy_slots[job_date] = []
                                busy_slots[job_date].append(job_slot)
                        except Exception as e:
                            print(f"Error processing job timestamp: {e}")

            # Generate availability for the next 7 days
            today = datetime.today()
            available_schedule = []

            for i in range(7):  # Next 7 days
                current_date = today + timedelta(days=i)
                day_name = current_date.strftime("%A")
                
                # Default: all slots available
                available_slots = list(slots.keys())
                
                # Check if any slots are already booked for this date
                if current_date.date() in busy_slots:
                    for booked_slot in busy_slots[current_date.date()]:
                        if booked_slot in available_slots:
                            available_slots.remove(booked_slot)

                # For today, remove slots that have already passed
                if current_date.date() == today.date():
                    current_hour = today.hour
                    if current_hour >= 12:  # After 12:00 PM
                        if "Slot 1" in available_slots:
                            available_slots.remove("Slot 1")
                    if current_hour >= 17:  # After 5:00 PM
                        if "Slot 2" in available_slots:
                            available_slots.remove("Slot 2")
                    if current_hour >= 22:  # After 10:00 PM
                        if "Slot 3" in available_slots:
                            available_slots.remove("Slot 3")

                if available_slots:
                    date_str = current_date.strftime('%Y-%m-%d')
                    available_schedule.append({
                        "day": day_name,
                        "date": date_str,
                        "slots": available_slots
                    })
    
class ActionCheckHandymanSchedule(Action):
    def name(self):
        return "action_check_availability"

    def run(self, dispatcher, tracker, domain):
        handyman_name = tracker.get_slot("handyman_name")
        if not handyman_name:
            dispatcher.utter_message(text="Please specify which handyman you'd like to check.")
            return []

        # Database references
        handymen_ref = db.reference('/handymen')
        jobs_ref = db.reference('/jobs')
        
        handymen_data = handymen_ref.get()
        jobs_data = jobs_ref.get() or {}

        # Find the handyman by name
        handyman = None
        handyman_id = None
        for h_id, h_data in handymen_data.items():
            if handyman_name.lower() in h_data.get("name", "").lower():
                handyman = h_data
                handyman_id = h_id
                break
                
        # Debug print to see what data we're working with
        print(f"DEBUG - Handyman data: {handyman}")
        print(f"DEBUG - Jobs data: {len(jobs_data) if jobs_data else 0} jobs found")
                
        if not handyman:
            dispatcher.utter_message(text=f"Sorry, I couldn't find any handyman named {handyman_name}.")
            return []

        # Define standard time slots
        slots = {
            "Slot 1": ("08:00 AM", "12:00 PM"),
            "Slot 2": ("01:00 PM", "05:00 PM"),
            "Slot 3": ("06:00 PM", "10:00 PM"),
        }

        # Find existing jobs for this handyman
        busy_slots = {}
        if jobs_data:
            for job_id, job in jobs_data.items():
                if job.get("assigned_to") == handyman_id and job.get("status") in ["Pending", "In-Progress"]:
                    try:
                        job_timestamp = job.get("starttimestamp", "")
                        if not job_timestamp:
                            continue
                            
                        # Parse the timestamp properly
                        if "T" in job_timestamp:
                            job_date_str = job_timestamp.split("T")[0]
                            job_date = datetime.strptime(job_date_str, "%Y-%m-%d").date()
                            job_slot = job.get("assigned_slot")
                            
                            if job_date not in busy_slots:
                                busy_slots[job_date] = []
                            busy_slots[job_date].append(job_slot)
                    except Exception as e:
                        print(f"Error processing job timestamp: {e}")

        # Debug print
        print(f"DEBUG - Busy slots: {busy_slots}")

        # Generate availability for the next 7 days
        today = datetime.today()
        available_schedule = []

        # First check if you have any available slots at all
        has_available_slots = False

        for i in range(7):  # Next 7 days
            current_date = today + timedelta(days=i)
            day_name = current_date.strftime("%A")
            
            # Default: all slots available
            available_slots = list(slots.keys())
            
            # Check if any slots are already booked for this date
            if current_date.date() in busy_slots:
                for booked_slot in busy_slots[current_date.date()]:
                    if booked_slot in available_slots:
                        available_slots.remove(booked_slot)

            # For today, remove slots that have already passed
            if current_date.date() == today.date():
                current_hour = today.hour
                if current_hour >= 12:  # After 12:00 PM
                    if "Slot 1" in available_slots:
                        available_slots.remove("Slot 1")
                if current_hour >= 17:  # After 5:00 PM
                    if "Slot 2" in available_slots:
                        available_slots.remove("Slot 2")
                if current_hour >= 22:  # After 10:00 PM
                    if "Slot 3" in available_slots:
                        available_slots.remove("Slot 3")

            if available_slots:
                has_available_slots = True
                date_str = current_date.strftime('%Y-%m-%d')
                available_schedule.append(
                    f"{day_name} ({date_str}): {', '.join(available_slots)}"
                )

        # Format response
        if available_schedule:
            response = f"{handyman_name} is available at the following times:\n" + "\n".join(available_schedule)
        else:
            response = f"Sorry, {handyman_name} has no available slots in the next 7 days."

        dispatcher.utter_message(text=response)
        return [SlotSet("handyman_name", handyman_name)]

class ActionConfirmBooking(Action):
    def name(self):
        return "action_confirm_booking"

    def run(self, dispatcher, tracker, domain):
        chosen_slot = tracker.get_slot("chosen_slot")
        chosen_date = tracker.get_slot("chosen_date")
        handyman_name = tracker.get_slot("handyman_name")
        handyman_id = tracker.get_slot("handyman_id")
        problem = tracker.get_slot("problem")
        user_id = tracker.sender_id

        if not all([chosen_slot, chosen_date, handyman_name, handyman_id, problem]):
            dispatcher.utter_message(text="I'm missing some information for your booking. Please specify the date, time slot, handyman, and service needed.")
            return []

        # Map slots to times
        slot_times = {
            "Slot 1": ("08:00", "12:00"),
            "Slot 2": ("13:00", "17:00"),
            "Slot 3": ("18:00", "22:00")
        }

        if chosen_slot in slot_times:
            start_time, end_time = slot_times[chosen_slot]

            # Convert chosen_date and slot times to ISO 8601 format without milliseconds
            try:
                date_format = "%Y-%m-%d"
                start_datetime = datetime.strptime(chosen_date, date_format).replace(
                    hour=int(start_time.split(":")[0]),
                    minute=int(start_time.split(":")[1])
                )
                end_datetime = datetime.strptime(chosen_date, date_format).replace(
                    hour=int(end_time.split(":")[0]),
                    minute=int(end_time.split(":")[1])
                )
                
                # Format timestamps to match the expected format (with .000Z)
                start_timestamp = start_datetime.strftime("%Y-%m-%dT%H:%M:%S.000Z")
                end_timestamp = end_datetime.strftime("%Y-%m-%dT%H:%M:%S.000Z")
                
                # Get user's address from Firebase if available
                user_ref = db.reference(f'/users/{user_id}')
                user_data = user_ref.get() or {}
                
                address = "Default Address"
                latitude = 3.1751817
                longitude = 101.6173767
                
                # Fix address parsing in ActionShowBookingDetails 
                if user_data and 'primaryAddress' in user_data:
                    address_data = user_data['primaryAddress']
                    address_parts = []
                    
                    # Use the actual field names from your Firebase structure
                    if 'unitName' in address_data and address_data['unitName']:
                        address_parts.append(address_data['unitName'])
                    
                    if 'buildingName' in address_data and address_data['buildingName']:
                        address_parts.append(address_data['buildingName'])
                    
                    if 'streetName' in address_data and address_data['streetName']:
                        address_parts.append(address_data['streetName'])
                    
                    if 'city' in address_data and address_data['city']:
                        address_parts.append(address_data['city'])
                    
                    if 'postalCode' in address_data and address_data['postalCode']:
                        address_parts.append(address_data['postalCode'])
                    
                    if 'country' in address_data and address_data['country']:
                        address_parts.append(address_data['country'])
                    
                    if address_parts:
                        address = ", ".join(address_parts)
                    
                    # Get coordinates if available
                    if 'latitude' in address_data and 'longitude' in address_data:
                        latitude = address_data['latitude']
                        longitude = address_data['longitude']
                
                # Get handyman's expertise that matches the user's problem
                handymen_ref = db.reference('/handymen')
                handymen_data = handymen_ref.get() or {}
                handyman_data = handymen_data.get(handyman_id, {})
                
                # Get the expertise array or create empty list if not found
                expertise_list = handyman_data.get("expertise", [])
                
                # Select the specific expertise that matches the user's problem
                category = "General"
                if isinstance(expertise_list, list):
                    # Try to find exact match first
                    for exp in expertise_list:
                        if problem.lower() in exp.lower():
                            category = exp
                            break
                    # If no match found, just use the first expertise or the problem description
                    if category == "General" and expertise_list:
                        category = expertise_list[0]
                elif isinstance(expertise_list, str):
                    category = expertise_list
                
                # If still no category, use the problem as the category
                if category == "General" and problem:
                    # Capitalize the first letter of each word in the problem
                    category = " ".join(word.capitalize() for word in problem.split())
                
                # Generate a booking ID
                booking_id = str(uuid.uuid4())
                
                # Create the booking in the correct format
                booking_data = {
                    "booking_id": booking_id,
                    "assigned_slot": chosen_slot,
                    "assigned_to": handyman_id,  # This was missing in your original code
                    "description": problem,
                    "category": category,
                    "endtimestamp": end_timestamp,
                    "starttimestamp": start_timestamp,
                    "status": "Pending",
                    "user_id": user_id,
                    "created_at": datetime.now().strftime("%Y-%m-%dT%H:%M:%S.%fZ")[:-3] + "Z",
                    "hasMaterials": False,
                    "address": address,
                    "latitude": latitude,
                    "longitude": longitude
                }
                
                # Save the booking to Firebase
                ref = db.reference(f"/jobs/{booking_id}")
                ref.set(booking_data)
                
                # Add booking fee transaction
                txn_ref = db.reference("/walletTransactions")
                txn_id = str(uuid.uuid4())

                # Get standard booking fee from fare table
                fare_ref = db.reference('/fare')
                fare_data = fare_ref.get() or {}
                booking_fee = fare_data.get('amount', 20)  # Default to 20 if not found

                txn_ref.child(txn_id).set({
                    "amount": -booking_fee,  # Use the value from fare table instead of hardcoded -20
                    "bookingId": booking_id,
                    "description": f"Processing fee for booking {booking_id}",
                    "timestamp": int(datetime.now().timestamp() * 1000),
                    "transactionType": "booking-fee",
                    "userId": user_id
                })

                confirmation_message = (
                    f"✅ Your booking is confirmed!\n\n"
                    f"Handyman: {handyman_name}\n"
                    f"Service: {category}\n"
                    f"Date: {chosen_date}\n"
                    f"Time: {slot_times[chosen_slot][0]} - {slot_times[chosen_slot][1]}\n\n"
                    f"A processing fee of RM{booking_fee} has been charged. You can view your booking details in the app."
                )
                dispatcher.utter_message(text=confirmation_message)

                return [SlotSet("booking_confirmed", True), SlotSet("booking_id", booking_id)]
            
            except Exception as e:
                print(f"Error creating booking: {e}")
                dispatcher.utter_message(text="Sorry, there was a problem creating your booking. Please try again.")
                return []

        else:
            dispatcher.utter_message(text=f"I couldn't find a handyman named '{handyman_name}'. Could you please choose from the list of available experts?")
            return []
    
class ActionCancelBooking(Action):
    def name(self):
        return "action_cancel_booking"

    def run(self, dispatcher, tracker, domain):
        booking_id = tracker.get_slot("booking_id")
        
        if booking_id:
            # Update the booking status in Firebase
            ref = db.reference(f"/jobs/{booking_id}")
            booking_data = ref.get()
            
            if booking_data:
                ref.update({"status": "Cancelled"})
                dispatcher.utter_message(text=f"Your booking has been canceled. The booking fee is non-refundable.")
            else:
                dispatcher.utter_message(text="I couldn't find your booking in the system.")
        else:
            dispatcher.utter_message(text="No active booking found to cancel.")
        
        # Reset booking-related slots
        return [
            SlotSet("handyman_name", None),
            SlotSet("handyman_id", None),
            SlotSet("chosen_date", None),
            SlotSet("chosen_slot", None),
            SlotSet("booking_confirmed", False),
            SlotSet("booking_id", None),
        ]

class ActionShowBookingDetails(Action):
    def name(self):
        return "action_show_booking_details"

    def run(self, dispatcher, tracker, domain):
        # Get slot values
        chosen_slot = tracker.get_slot("chosen_slot")
        chosen_date = tracker.get_slot("chosen_date")
        handyman_name = tracker.get_slot("handyman_name")
        handyman_id = tracker.get_slot("handyman_id")
        problem = tracker.get_slot("problem")
        user_id = tracker.sender_id
        
        # Map slots to readable time
        slot_times = {
            "Slot 1": "8:00 AM - 12:00 PM",
            "Slot 2": "1:00 PM - 5:00 PM",
            "Slot 3": "6:00 PM - 10:00 PM"
        }
        
        # If handyman_id is missing but we have the name, try to find the ID
        if not handyman_id and handyman_name:
            # Look up the handyman ID from the name
            handymen_ref = db.reference('/handymen')
            handymen_data = handymen_ref.get() or {}
            
            for h_id, h_data in handymen_data.items():
                if handyman_name.lower() in h_data.get("name", "").lower():
                    handyman_id = h_id
                    print(f"Retrieved handyman_id: {handyman_id} for {handyman_name}")
                    break
        
        if not all([chosen_slot, chosen_date, handyman_name]):
            dispatcher.utter_message(text="I'm missing some booking information. Please provide the handyman name, date, and time slot.")
            return []
        
        # Get the standard booking fee from the database
        fare_ref = db.reference('/fare')
        fare_data = fare_ref.get() or {}
        booking_fee = fare_data.get('amount', 20)  # Default to 20 if not specified
        
        # Get user's wallet balance
        user_ref = db.reference(f'/users/{user_id}')
        user_data = user_ref.get() or {}
        wallet_balance = user_data.get('wallet', 0)
        
        # Get user's address for display
        address = "Default Address"
        if user_data and 'primaryAddress' in user_data:
            address_data = user_data['primaryAddress']
            address_parts = []
            
            # Use the actual field names from your Firebase structure
            if 'unitName' in address_data and address_data['unitName']:
                address_parts.append(address_data['unitName'])
            
            if 'buildingName' in address_data and address_data['buildingName']:
                address_parts.append(address_data['buildingName'])
            
            if 'streetName' in address_data and address_data['streetName']:
                address_parts.append(address_data['streetName'])
            
            if 'city' in address_data and address_data['city']:
                address_parts.append(address_data['city'])
            
            if 'postalCode' in address_data and address_data['postalCode']:
                address_parts.append(address_data['postalCode'])
            
            if 'country' in address_data and address_data['country']:
                address_parts.append(address_data['country'])
            
            if address_parts:
                address = ", ".join(address_parts)
            
            # Get coordinates if available
            if 'latitude' in address_data and 'longitude' in address_data:
                latitude = address_data['latitude']
                longitude = address_data['longitude']
        
        # Format the booking details
        time_display = slot_times.get(chosen_slot, chosen_slot)
        
        booking_details = (
            f"Here's your booking summary:\n\n"
            f"Handyman: {handyman_name}\n"
            f"Date: {chosen_date}\n"
            f"Time: {time_display}\n"
            f"Problem: {problem or 'Not specified'}\n"
            f"Booking Fee: RM{booking_fee}\n"
            f"Address: {address}\n\n"
        )
        
        # Check if user has enough balance for the booking fee
        if wallet_balance < booking_fee:
            insufficient_funds_message = (
                f"{booking_details}"
                f"❌ Looks like you don't have sufficient funds for the booking fee.\n"
                f"Your current balance: RM{wallet_balance}\n"
                f"Required amount: RM{booking_fee}\n\n"
                f"Please top up your wallet before confirming this booking."
            )
            
            dispatcher.utter_message(
                text=insufficient_funds_message,
                buttons=[
                    {"payload": "/cancel_request", "title": "Cancel"},
                ]
            )
        else:
            confirmation_message = (
                f"{booking_details}"
                f"Would you like to confirm this booking?"
            )
            
            dispatcher.utter_message(
                text=confirmation_message,
                buttons=[
                    {"payload": "/confirm_booking", "title": "Confirm Booking"},
                    {"payload": "/cancel_request", "title": "Cancel"}
                ]
            )
        
        # Always return the handyman_id to ensure it's available for ActionConfirmBooking
        return [SlotSet("handyman_id", handyman_id)]

class ActionEasyBook(Action):
    """
    Handles the "easy booking" flow - a streamlined one-step booking process
    where the AI extracts all needed information from a single user message
    and automatically selects the best handyman based on expertise, rating,
    and availability.
    
    This differs from the standard multi-step flow by:
    1. Automatically extracting date and time from a free text
    2. Identifying the problem type using report_issue intent keywords
    3. Selecting the best handyman automatically without user intervention
    4. Only requiring user confirmation to complete the booking
    """
    def name(self):
        return "action_easy_book"

    def is_nearby_city(self, city_graph, city1, city2):
        """Check if city2 is within the defined radius of city1"""
        if not city_graph:
            return False
            
        # Normalize city names to lowercase for case-insensitive comparison
        city1_lower = city1.lower() if city1 else ""
        city2_lower = city2.lower() if city2 else ""
        
        # Debug output
        print(f"Checking if {city2_lower} is near {city1_lower}")
        
        # First try direct lookup
        if city1_lower in city_graph and city2_lower in city_graph[city1_lower]:
            print(f"Direct match found: {city2_lower} is {city_graph[city1_lower][city2_lower]} km from {city1_lower}")
            return True
            
        # If no match, check for partial matches (e.g., "Petaling Jaya" might be stored as "petaling jaya")
        for graph_city in city_graph:
            if city1_lower in graph_city or graph_city in city1_lower:
                for nearby_city in city_graph[graph_city]:
                    if city2_lower in nearby_city or nearby_city in city2_lower:
                        print(f"Partial match found: {nearby_city} is {city_graph[graph_city][nearby_city]} km from {graph_city}")
                        return True
        
        print(f"No proximity match found between {city1_lower} and {city2_lower}")
        return False
        
    def get_distance(self, city_graph, city1, city2):
        """Get the distance between two cities"""
        if not city_graph:
            return float('inf')
            
        # Normalize city names to lowercase
        city1_lower = city1.lower() if city1 else ""
        city2_lower = city2.lower() if city2 else ""
        
        # First try direct lookup
        if city1_lower in city_graph and city2_lower in city_graph[city1_lower]:
            return city_graph[city1_lower][city2_lower]
            
        # If no direct match, check for partial matches
        for graph_city in city_graph:
            if city1_lower in graph_city or graph_city in city1_lower:
                for nearby_city in city_graph[graph_city]:
                    if city2_lower in nearby_city or nearby_city in city2_lower:
                        return city_graph[graph_city][nearby_city]
        
        return float('inf')
        
    def _add_handyman_with_city_distance(self, h_data, user_city, nearby_handymen, other_handymen):
        """Helper method to add handyman with city-based distance calculation"""
        handyman_city = h_data.get("city", "").lower() if h_data.get("city") else ""
        if not user_city or not handyman_city:
            # If we don't have city information, add to other_handymen
            other_handymen.append(h_data)
            return
            
        # Check exact city match first
        if handyman_city == user_city.lower():
            h_data["distance"] = 0  # Same city, assume very close
            nearby_handymen.append(h_data)
            return
            
        # Try the city graph
        try:
            if self.is_nearby_city(city_map.city_graph, user_city.lower(), handyman_city):
                h_data["distance"] = self.get_distance(city_map.city_graph, user_city.lower(), handyman_city)
                nearby_handymen.append(h_data)
                return
        except Exception as e:
            print(f"Error checking city proximity: {e}")
            
        # If all checks fail, calculate an approximate distance based on Selangor/KL region average
        # This ensures we still consider handymen without exact matches but in general area
        nearby_cities = self._check_general_area_proximity(user_city, handyman_city)
        if nearby_cities:
            h_data["distance"] = 30  # Assume ~30km if in general KL/Selangor area but exact distance unknown
            nearby_handymen.append(h_data)
        else:
            # Not in nearby area, add to other_handymen
            other_handymen.append(h_data)
            
    def _check_general_area_proximity(self, city1, city2):
        """Check if two cities are in the same general metropolitan area"""
        # Define KL/Selangor area cities
        kl_selangor_cities = [
            'kuala lumpur', 'petaling jaya', 'shah alam', 'subang jaya', 'klang',
            'ampang', 'cheras', 'puchong', 'kajang', 'seri kembangan', 'cyberjaya',
            'putrajaya', 'bangi', 'rawang', 'sentul', 'mont kiara', 'bangsar',
            'damansara', 'gombak', 'kepong', 'setapak'
        ]
        
        # Check if both cities are in the KL/Selangor area
        return (city1.lower() in kl_selangor_cities and 
                city2.lower() in kl_selangor_cities)

    def haversine(self, lat1, lon1, lat2, lon2):
        """Calculate the great circle distance between two points in kilometers"""
        # Convert to radians
        lat1, lon1, lat2, lon2 = map(radians, [lat1, lon1, lat2, lon2])
        # Haversine calculation
        dlon = lon2 - lon1 
        dlat = lat2 - lat1 
        a = sin(dlat/2)**2 + cos(lat1) * cos(lat2) * sin(dlon/2)**2
        c = 2 * asin(sqrt(a)) 
        km = 6371 * c  # Earth radius in kilometers
        return km
        
    def run(self, dispatcher, tracker, domain):
        # Extract user input
        user_message = tracker.latest_message.get("text", "")
        print(f"Processing easy book request: {user_message}")
        
        # STEP 0: Preprocess user message to extract problem separately
        # First, let's remove date/time patterns that interfere with problem detection
        # Common date patterns: DD/MM, MM/DD, DD-MM
        date_time_patterns = [
            r'\d{1,2}[/-]\d{1,2}',                # Date patterns like 29/5 or 5-29
            r'\d{1,2}(?::\d{2})?\s*(?:am|pm|AM|PM)?', # Time patterns like 3pm, 15:00, etc
            r'(?:at|on)\s+\d{1,2}[/-]\d{1,2}',    # "at 29/5"
            r'(?:at|on)\s+\d{1,2}(?::\d{2})?\s*(?:am|pm|AM|PM)?', # "at 3pm"
            r'tomorrow',
            r'today',
            r'next week',
            r'next month'
        ]
        
        # Save original message for date/time extraction later
        original_message = user_message
        
        # Remove date/time patterns for problem identification
        problem_only_text = user_message
        for pattern in date_time_patterns:
            problem_only_text = re.sub(pattern, '', problem_only_text, flags=re.IGNORECASE)
        
        # Also remove booking-related phrases that aren't relevant to the problem
        booking_phrases = [
            r'i want to book',
            r'i wanna book',
            r'i need to book',
            r'book a',
            r'book an',
            r'schedule a',
            r'schedule an',
            r'i want to schedule',
            r'i need a handyman',
            r'i need a',
            r'please book'
            r'please schedule',
            r'Book Handyman',
            r'Book a handyman',
            r'Book an expert',
            r'Book a service',
            r'Book a technician',
            r'Book a repair',
        ]
        
        for phrase in booking_phrases:
            problem_only_text = re.sub(phrase, '', problem_only_text, flags=re.IGNORECASE)
            
        # Clean up extra spaces
        problem_only_text = re.sub(r'\s+', ' ', problem_only_text).strip()
        
        print(f"Extracted problem text: {problem_only_text}")
        
        # STEP 1: Extract date from the original message
        # Extract date from message (looking for patterns like DD/MM, MM/DD)
        date_match = re.search(r'(\d{1,2})[/-](\d{1,2})', original_message)
        extracted_date = None
        if date_match:
            day, month = int(date_match.group(1)), int(date_match.group(2))
            # Assume current year
            current_year = datetime.now().year
            try:
                extracted_date = datetime(current_year, month, day).strftime('%Y-%m-%d')
                print(f"Extracted date: {extracted_date}")
            except ValueError:
                # Try swapping day and month in case of different format
                try:
                    extracted_date = datetime(current_year, day, month).strftime('%Y-%m-%d')
                    print(f"Swapped date: {extracted_date}")
                except ValueError:
                    pass
        
        # If no date found, default to tomorrow
        if not extracted_date:
            tomorrow = datetime.now() + timedelta(days=1)
            extracted_date = tomorrow.strftime('%Y-%m-%d')
            print(f"Using default date (tomorrow): {extracted_date}")
        
        # STEP 2: Extract time with higher priority on AM/PM format
        # First look for explicit time with AM/PM indicator (like 10:30am)
        time_match = re.search(r'\b(\d{1,2})(?::(\d{2}))?\s*([aApP][mM])\b', original_message)
        
        if not time_match:
            # Fallback: Try 24-hour format only if no AM/PM format found
            time_match = re.search(r'\b(\d{1,2}):(\d{2})\b', original_message)
            
        slot = None
        extracted_time = None
        if time_match:
            hour = int(time_match.group(1))
            # Handle different capturing groups based on which regex matched
            if len(time_match.groups()) > 2 and time_match.group(3):  # AM/PM format matched
                minute = int(time_match.group(2)) if time_match.group(2) else 0
                am_pm = time_match.group(3)
                print(f"Matched AM/PM format time: {hour}:{minute:02d} {am_pm}")
            else:  # 24-hour format matched
                minute = int(time_match.group(2))
                am_pm = None
                print(f"Matched 24-hour format time: {hour}:{minute:02d}")
            
            # Convert to 24-hour format if am/pm specified
            if am_pm and am_pm.lower() == 'pm' and hour < 12:
                hour += 12
            elif am_pm and am_pm.lower() == 'am' and hour == 12:
                hour = 0
                
            # Now hour is in 24-hour format
            hour_24 = hour
            print(f"Converted to 24-hour: {hour_24}:{minute:02d}")
            
            # Format the extracted time for debugging
            minute_str = f":{minute:02d}"
            period = "AM" if hour < 12 else "PM"
            display_hour = hour if hour <= 12 else hour - 12
            display_hour = 12 if display_hour == 0 else display_hour
            extracted_time = f"{display_hour}{minute_str} {period}"
            print(f"Extracted time: {extracted_time}")
            
            # Determine slot based on hour, with clearer boundaries
            if 8 <= hour_24 < 12:
                slot = "Slot 1"  # 8am-12pm
                print(f"Selected Slot 1 (morning) for {extracted_time}")
            elif 12 <= hour_24 < 17:
                slot = "Slot 2"  # 1pm-5pm
                print(f"Selected Slot 2 (afternoon) for {extracted_time}")
            elif 17 <= hour_24 < 22:
                slot = "Slot 3"  # 6pm-10pm
                print(f"Selected Slot 3 (evening) for {extracted_time}")
            else:
                print(f"Time {extracted_time} is outside booking hours, using default")
                
        # If no specific time found, pick Slot 2 (afternoon) as default
        if not slot:
            slot = "Slot 2"
            print(f"Using default slot: {slot}")
        
        # Define readable slot time ranges for display
        slot_display_times = {
            "Slot 1": "8:00 AM - 12:00 PM",
            "Slot 2": "1:00 PM - 5:00 PM",
            "Slot 3": "6:00 PM - 10:00 PM"
        }
        
        # Get the slot time display for the selected slot
        slot_time_display = slot_display_times.get(slot, slot)
        
        # STEP 3: Identify the problem type using intent classification
        # Use the problem_only_text instead of full message for intent classification
        problem_text = problem_only_text.lower()
        
        # Call Rasa API to classify the problem text
        intent_name, intent_confidence = classify_text_with_rasa_server(problem_text)
        required_expertise = expertise_mapping.get(intent_name)
        
        # If we couldn't determine the expertise from intent or confidence is too low
        if not required_expertise or intent_name == 'easy_book' or intent_confidence < 0.5:
            print(f"Intent detection insufficient ({intent_name}, confidence: {intent_confidence}), trying secondary intents")
            
            # Check for secondary intents (like ActionSuggestHandyman does)
            intent_ranking = tracker.latest_message.get('intent_ranking', [])
            for ranked_intent in intent_ranking:
                intent_id = ranked_intent.get('name', '')
                confidence = ranked_intent.get('confidence', 0)
                if intent_id.startswith('report_issue_') and confidence > 0.3:
                    required_expertise = expertise_mapping.get(intent_id)
                    print(f"Found secondary intent {intent_id} with confidence {confidence}")
                    break
        
        # If still no expertise found, use General
        if not required_expertise:
            required_expertise = "General"
            print(f"No specific expertise detected, using General")
            
        # STEP 4: Find the best available handyman based on:
        # - Expertise match
        # - User's location (prioritize by actual distance using coordinates)
        # - Rating (highest first)
        user_id = tracker.sender_id
        
        # Get user's location data from Firebase
        user_ref = db.reference(f'/users/{user_id}')
        user_data = user_ref.get() or {}
        
        user_city = None
        user_latitude = None
        user_longitude = None
        
        if user_data and 'primaryAddress' in user_data:
            user_city = user_data['primaryAddress'].get('city')
            user_latitude = user_data['primaryAddress'].get('latitude')
            user_longitude = user_data['primaryAddress'].get('longitude')
            
        if not user_city:
            user_city = tracker.get_slot("location")
        
        print(f"User location - City: {user_city}, Coordinates: {user_latitude}, {user_longitude}")
            
        # Find handymen of the required expertise
        ref = db.reference('/handymen')
        handymen_data = ref.get() or {}
        
        # Group handymen by distance categories
        nearby_handymen = []  # Handymen with calculable distance
        other_handymen = []   # Handymen with unknown distance
        
        for h_id, h_data in handymen_data.items():
            if (h_data.get("expertise") and 
                h_data.get("status") == "active" and
                isinstance(h_data["expertise"], list) and
                any(required_expertise.lower() in exp.lower() for exp in h_data["expertise"] if isinstance(exp, str))):
                
                h_data["id"] = h_id  # Add ID to the data
                
                # Calculate distance if we have coordinates for both user and handyman
                if user_latitude and user_longitude and h_data.get('latitude') and h_data.get('longitude'):
                    try:
                        distance = self.haversine(
                            float(user_latitude), 
                            float(user_longitude), 
                            float(h_data.get('latitude')), 
                            float(h_data.get('longitude'))
                        )
                        h_data["distance"] = round(distance, 2)
                        nearby_handymen.append(h_data)
                        print(f"Calculated distance to {h_data.get('name')}: {h_data['distance']} km")
                    except (ValueError, TypeError) as e:
                        print(f"Error calculating distance for {h_data.get('name')}: {e}")
                        # Even if distance calculation fails, still consider them based on city
                        self._add_handyman_with_city_distance(h_data, user_city, nearby_handymen, other_handymen)
                else:
                    # Fall back to city-based grouping if coordinates are missing
                    self._add_handyman_with_city_distance(h_data, user_city, nearby_handymen, other_handymen)
                    
        # Sort all nearby handymen by a combined score of rating and distance
        if nearby_handymen:
            # Debug print all nearby handymen
            print(f"DEBUG: Found {len(nearby_handymen)} handymen with distance:")
            for h in nearby_handymen:
                print(f"  - {h.get('name')} in {h.get('city')} (Distance: {h.get('distance', 'unknown')} km, Rating: {h.get('average_rating', 0) or h.get('rating', 0)})")
            
            # Sort by actual distance first, then by rating as tiebreaker
            nearby_handymen = sorted(
                nearby_handymen,
                key=lambda x: (x.get("distance", 100), -(x.get("average_rating", 0) or x.get("rating", 0)))
            )
            
            # After sorting, check for availability instead of just picking the first one
            # Check the handymen's existing jobs to determine availability
            jobs_ref = db.reference('/jobs')
            jobs_data = jobs_ref.get() or {}
            
            # Convert requested booking date to datetime.date object for comparison
            booking_date = datetime.strptime(extracted_date, "%Y-%m-%d").date()
            print(f"Looking for handymen available on {booking_date} for {slot}")
            
            # Find an available handyman by checking each one's schedule
            selected_handyman = None
            for candidate in nearby_handymen:
                handyman_id = candidate.get("id")
                handyman_name = candidate.get("name", "Unknown")
                print(f"Checking availability for {handyman_name} (ID: {handyman_id})")
                
                # Find existing jobs for this handyman
                handyman_busy_slots = {}
                is_available = True
                
                if jobs_data:
                    for job_id, job in jobs_data.items():
                        if job.get("assigned_to") == handyman_id and job.get("status") in ["Pending", "In-Progress"]:
                            try:
                                job_timestamp = job.get("starttimestamp", "")
                                if not job_timestamp:
                                    continue
                                    
                                # Parse the timestamp properly
                                if "T" in job_timestamp:
                                    job_date_str = job_timestamp.split("T")[0]
                                    job_date = datetime.strptime(job_date_str, "%Y-%m-%d").date()
                                    job_slot = job.get("assigned_slot")
                                    
                                    if job_date not in handyman_busy_slots:
                                        handyman_busy_slots[job_date] = []
                                    handyman_busy_slots[job_date].append(job_slot)
                                    
                                    # If this job conflicts with our requested date and slot
                                    if job_date == booking_date and job_slot == slot:
                                        is_available = False
                                        print(f"Handyman {handyman_name} is busy on {job_date} for {job_slot}")
                            except Exception as e:
                                print(f"Error processing job timestamp: {e}")
                
                # Check if handyman is available for the requested date/slot
                if is_available:
                    print(f"Found available handyman: {handyman_name}")
                    selected_handyman = candidate
                    break
                    
            # If we couldn't find any available handyman in nearby_handymen, check other_handymen
            if not selected_handyman and other_handymen:
                print("No nearby handymen available, checking handymen from other locations")
                for candidate in other_handymen:
                    handyman_id = candidate.get("id")
                    handyman_name = candidate.get("name", "Unknown")
                    print(f"Checking availability for {handyman_name} (ID: {handyman_id})")
                    
                    # Find existing jobs for this handyman
                    handyman_busy_slots = {}
                    is_available = True
                    
                    if jobs_data:
                        for job_id, job in jobs_data.items():
                            if job.get("assigned_to") == handyman_id and job.get("status") in ["Pending", "In-Progress"]:
                                try:
                                    job_timestamp = job.get("starttimestamp", "")
                                    if not job_timestamp:
                                        continue
                                        
                                    # Parse the timestamp properly
                                    if "T" in job_timestamp:
                                        job_date_str = job_timestamp.split("T")[0]
                                        job_date = datetime.strptime(job_date_str, "%Y-%m-%d").date()
                                        job_slot = job.get("assigned_slot")
                                        
                                        if job_date not in handyman_busy_slots:
                                            handyman_busy_slots[job_date] = []
                                        handyman_busy_slots[job_date].append(job_slot)
                                        
                                        # If this job conflicts with our requested date and slot
                                        if job_date == booking_date and job_slot == slot:
                                            is_available = False
                                            print(f"Handyman {handyman_name} is busy on {job_date} for {job_slot}")
                                except Exception as e:
                                    print(f"Error processing job timestamp: {e}")
                    
                    # Check if handyman is available for the requested date/slot
                    if is_available:
                        print(f"Found available handyman: {handyman_name}")
                        selected_handyman = candidate
                        break
            
            # If still no available handyman found
            if not selected_handyman:
                dispatcher.utter_message(
                    text=f"Sorry, all {required_expertise} experts are fully booked for {slot_time_display} on {extracted_date}. Please try another time or date."
                )
                return []
        elif other_handymen:
            other_handymen = sorted(other_handymen, 
                                   key=lambda x: x.get("average_rating", 0) or x.get("rating", 0), 
                                   reverse=True)
                                   
            # After sorting, check for availability instead of just picking the first one
            # Check the handymen's existing jobs to determine availability
            jobs_ref = db.reference('/jobs')
            jobs_data = jobs_ref.get() or {}
            
            # Convert requested booking date to datetime.date object for comparison
            booking_date = datetime.strptime(extracted_date, "%Y-%m-%d").date()
            print(f"Looking for handymen available on {booking_date} for {slot}")
            
            # Find an available handyman by checking each one's schedule
            selected_handyman = None
            for candidate in other_handymen:
                handyman_id = candidate.get("id")
                handyman_name = candidate.get("name", "Unknown")
                print(f"Checking availability for {handyman_name} (ID: {handyman_id})")
                
                # Find existing jobs for this handyman
                handyman_busy_slots = {}
                is_available = True
                
                if jobs_data:
                    for job_id, job in jobs_data.items():
                        if job.get("assigned_to") == handyman_id and job.get("status") in ["Pending", "In-Progress"]:
                            try:
                                job_timestamp = job.get("starttimestamp", "")
                                if not job_timestamp:
                                    continue
                                    
                                # Parse the timestamp properly
                                if "T" in job_timestamp:
                                    job_date_str = job_timestamp.split("T")[0]
                                    job_date = datetime.strptime(job_date_str, "%Y-%m-%d").date()
                                    job_slot = job.get("assigned_slot")
                                    
                                    if job_date not in handyman_busy_slots:
                                        handyman_busy_slots[job_date] = []
                                    handyman_busy_slots[job_date].append(job_slot)
                                    
                                    # If this job conflicts with our requested date and slot
                                    if job_date == booking_date and job_slot == slot:
                                        is_available = False
                                        print(f"Handyman {handyman_name} is busy on {job_date} for {job_slot}")
                            except Exception as e:
                                print(f"Error processing job timestamp: {e}")
                
                # Check if handyman is available for the requested date/slot
                if is_available:
                    print(f"Found available handyman: {handyman_name}")
                    selected_handyman = candidate
                    break
            
            # If no available handyman found
            if not selected_handyman:
                dispatcher.utter_message(
                    text=f"Sorry, all {required_expertise} experts are fully booked for {slot_time_display} on {extracted_date}. Please try another time or date."
                )
                return []
        else:
            dispatcher.utter_message(text=f"Sorry, I couldn't find any {required_expertise} expert available. Please try booking manually.")
            return []
        
        # STEP 5: Prepare booking with the selected top-rated handyman
        # Get the standard booking fee from the database
        fare_ref = db.reference('/fare')
        fare_data = fare_ref.get() or {}
        booking_fee = fare_data.get('amount', 20)  # Default to 20 if not specified
        
        # Get user's wallet balance
        user_ref = db.reference(f'/users/{user_id}')
        user_data = user_ref.get() or {}
        wallet_balance = user_data.get('wallet', 0)
        
        # Set slots for the booking
        handyman_name = selected_handyman.get('name', 'Unknown')
        handyman_id = selected_handyman.get('id')

        # Set these slots first so they're available for ActionConfirmBooking if needed
        events = [
            SlotSet("chosen_date", extracted_date),
            SlotSet("chosen_slot", slot),
            SlotSet("handyman_name", handyman_name),
            SlotSet("handyman_id", handyman_id),
            SlotSet("problem", problem_text)
        ]

        # Prepare response message
        response = (
            f"I'll book a top-rated {required_expertise} for you!\n\n"
            f"Handyman: {handyman_name}\n"
        )
        
        # Add location-based selection reasoning
        if selected_handyman.get('distance', float('inf')) < 5:  # Within 5km
            response += f"Location: Very close in {selected_handyman.get('city', 'Unknown location')} ({selected_handyman.get('distance')} km away)\n"
        elif selected_handyman.get('distance', float('inf')) < 15:  # Within 15km
            response += f"Location: Nearby in {selected_handyman.get('city', 'Unknown location')} ({selected_handyman.get('distance')} km away)\n"
        elif selected_handyman.get('distance', float('inf')) != float('inf'):
            response += f"Location: {selected_handyman.get('distance')} km away in {selected_handyman.get('city', 'Unknown location')}\n"
        else:
            response += f"Location: {selected_handyman.get('city', 'Unknown location')}\n"
            
        # Add rating information
        rating = selected_handyman.get("average_rating") or selected_handyman.get("rating", "Not rated")
        response += f"Rating: {rating}/5\n"
        
        # Continue with the rest of the details
        response += (
            f"Date: {extracted_date}\n"
            f"Time: {slot_time_display}\n"
            f"Problem: {problem_text}\n"
            f"Booking Fee: RM{booking_fee}\n\n"
        )
        
        # STEP 6: Check user's wallet balance to ensure they can afford the booking
        # Check if user has enough balance
        if wallet_balance < booking_fee:
            insufficient_funds_message = (
                f"{response}"
                f"❌ Uh oh! Looks like you need to top up your wallet.\n"
                f"Your current balance: RM{wallet_balance}\n"
                f"Required amount: RM{booking_fee}"
            )
            dispatcher.utter_message(text=insufficient_funds_message)
            return events
        else:
            # STEP 7: Either complete booking automatically if user clearly confirmed,
            # or ask for confirmation with buttons
            # Check if the message contains clear confirmation language 
            # like "book it", "confirm", etc.
            auto_confirm = any(phrase in user_message.lower() for phrase in [
                "book it", "confirm", "go ahead", "proceed", "book now", "do it"
            ])
            
            # If user already confirmed in their message, automatically complete the booking
            if auto_confirm:
                # Reuse the confirm booking action
                confirm_action = ActionConfirmBooking()
                return events + confirm_action.run(dispatcher, tracker, domain)
            else:
                # Otherwise ask for confirmation first
                confirmation_message = (
                    f"{response}"
                    f"The booking fee will be automatically deducted from your wallet. Wanna proceed?"
                )
                
                dispatcher.utter_message(
                    text=confirmation_message,
                    buttons=[
                        {"payload": "/confirm_booking", "title": "Yes, great!"},
                        {"payload": "/cancel_request", "title": "No, cancel"}
                    ]
                )
                
                return events

# Helper Functions

def get_matching_handymen(required_expertise, user_city):
    """
    Find handymen that match the required expertise and sort them by location and rating.
    
    Args:
        required_expertise: The type of expertise needed (e.g. 'Plumber', 'Electrician')
        user_city: The city where the user is located
        
    Returns:
        tuple: (city_handymen, other_handymen) - Lists of handymen sorted by rating
    """
    # Reference to handymen in the database
    ref = db.reference('/handymen')
    handymen_data = ref.get() or {}
    
    city_handymen = []
    other_handymen = []
    
    # Filter handymen based on expertise, city, and active status
    for h_id, h_data in handymen_data.items():
        if (h_data.get("expertise") and 
            h_data.get("status") == "active" and
            any(required_expertise.lower() in exp.lower() for exp in h_data["expertise"] if isinstance(exp, str))):
            
            h_data["id"] = h_id  # Add ID to the data
            
            # Check if handyman is in the same city as user
            if user_city and h_data.get("city") and h_data.get("city").lower() == user_city.lower():
                city_handymen.append(h_data)
            else:
                other_handymen.append(h_data)
    
    # Sort handymen by rating in descending order
    city_handymen = sorted(city_handymen, key=lambda x: x.get("average_rating", 0) or x.get("rating", 0), reverse=True)
    other_handymen = sorted(other_handymen, key=lambda x: x.get("average_rating", 0) or x.get("rating", 0), reverse=True)
    
    return city_handymen, other_handymen

def process_booking(dispatcher, tracker, user_id, handyman_id, handyman_name, chosen_date, chosen_slot, problem):
    """
    Process booking creation and store it in Firebase
    
    Args:
        dispatcher: Rasa dispatcher for sending messages
        tracker: Conversation tracker
        user_id: ID of the user making the booking
        handyman_id: ID of the selected handyman
        handyman_name: Name of the selected handyman
        chosen_date: Date for the booking
        chosen_slot: Selected time slot
        problem: Description of the problem
        
    Returns:
        tuple: (success, message, booking_id) - Booking status and related info
    """
    try:
        # Map slots to times
        slot_times = {
            "Slot 1": ("08:00", "12:00"),
            "Slot 2": ("13:00", "17:00"),
            "Slot 3": ("18:00", "22:00")
        }
        
        if chosen_slot not in slot_times:
            return False, "Invalid slot selected. Please try again.", None
            
        start_time, end_time = slot_times[chosen_slot]

        # Convert chosen_date and slot times to ISO 8601 format
        date_format = "%Y-%m-%d"
        start_datetime = datetime.strptime(chosen_date, date_format).replace(
            hour=int(start_time.split(":")[0]),
            minute=int(start_time.split(":")[1])
        )
        end_datetime = datetime.strptime(chosen_date, date_format).replace(
            hour=int(end_time.split(":")[0]),
            minute=int(end_time.split(":")[1])
        )
        
        # Format timestamps
        start_timestamp = start_datetime.strftime("%Y-%m-%dT%H:%M:%S.000Z")
        end_timestamp = end_datetime.strftime("%Y-%m-%dT%H:%M:%S.000Z")
        
        # Get user's address from Firebase if available
        user_ref = db.reference(f'/users/{user_id}')
        user_data = user_ref.get() or {}
        
        address = "Default Address"
        latitude = 3.1751817
        longitude = 101.6173767
        
        if user_data and 'primaryAddress' in user_data:
            address_data = user_data['primaryAddress']
            address_parts = []
            
            if 'unitName' in address_data and address_data['unitName']:
                address_parts.append(address_data['unitName'])
            
            if 'buildingName' in address_data and address_data['buildingName']:
                address_parts.append(address_data['buildingName'])
            
            if 'streetName' in address_data and address_data['streetName']:
                address_parts.append(address_data['streetName'])
            
            if 'city' in address_data and address_data['city']:
                address_parts.append(address_data['city'])
            
            if 'postalCode' in address_data and address_data['postalCode']:
                address_parts.append(address_data['postalCode'])
            
            if 'country' in address_data and address_data['country']:
                address_parts.append(address_data['country'])
            
            if address_parts:
                address = ", ".join(address_parts)
            
            # Get coordinates if available
            if 'latitude' in address_data and 'longitude' in address_data:
                latitude = address_data['latitude']
                longitude = address_data['longitude']
        
        # Get handyman's expertise that matches the user's problem
        handymen_ref = db.reference('/handymen')
        handymen_data = handymen_ref.get() or {}
        handyman_data = handymen_data.get(handyman_id, {})
        
        expertise_list = handyman_data.get("expertise", [])
        
        # Select the specific expertise that matches the user's problem
        category = "General"
        if isinstance(expertise_list, list):
            for exp in expertise_list:
                if problem.lower() in exp.lower():
                    category = exp
                    break
            if category == "General" and expertise_list:
                category = expertise_list[0]
        elif isinstance(expertise_list, str):
            category = expertise_list
        
        if category == "General" and problem:
            category = " ".join(word.capitalize() for word in problem.split())
        
        # Generate a booking ID
        booking_id = str(uuid.uuid4())
        
        # Create the booking
        booking_data = {
            "booking_id": booking_id,
            "assigned_slot": chosen_slot,
            "assigned_to": handyman_id,
            "description": problem,
            "category": category,
            "endtimestamp": end_timestamp,
            "starttimestamp": start_timestamp,
            "status": "Pending",
            "user_id": user_id,
            "created_at": datetime.now().strftime("%Y-%m-%dT%H:%M:%S.%fZ")[:-3] + "Z",
            "hasMaterials": False,
            "address": address,
            "latitude": latitude,
            "longitude": longitude
        }
        
        # Save the booking to Firebase
        ref = db.reference(f"/jobs/{booking_id}")
        ref.set(booking_data)
        
        # Add booking fee transaction
        txn_ref = db.reference("/walletTransactions")
        txn_id = str(uuid.uuid4())

        # Get standard booking fee from fare table
        fare_ref = db.reference('/fare')
        fare_data = fare_ref.get() or {}
        booking_fee = fare_data.get('amount', 20)  # Default to 20 if not found

        txn_ref.child(txn_id).set({
            "amount": -booking_fee,
            "bookingId": booking_id,
            "description": f"Processing fee for booking {booking_id}",
            "timestamp": int(datetime.now().timestamp() * 1000),
            "transactionType": "booking-fee",
            "userId": user_id
        })

        confirmation_message = (
            f"✅ Your booking is confirmed!\n\n"
            f"Handyman: {handyman_name}\n"
            f"Service: {category}\n"
            f"Date: {chosen_date}\n"
            f"Time: {slot_times[chosen_slot][0]} - {slot_times[chosen_slot][1]}\n\n"
            f"A processing fee of RM{booking_fee} has been charged. You can view your booking details in the app."
        )
        
        return True, confirmation_message, booking_id
        
    except Exception as e:
        print(f"Error creating booking: {e}")
        return False, "Sorry, there was a problem creating your booking. Please try again.", None

class ActionCancelRequest(Action):
    """
    Handles cancellation of booking requests or any ongoing booking process.
    This action is triggered when a user clicks "Cancel" or sends a cancel request.
    """
    def name(self):
        return "action_cancel_request"

    def run(self, dispatcher, tracker, domain):
        # Clear all booking-related slots
        dispatcher.utter_message(text="I've cancelled your booking request. Is there anything else I can help you with?")
        
        # Reset all booking-related slots but keep user information
        return [
            SlotSet("handyman_name", None),
            SlotSet("handyman_id", None),
            SlotSet("chosen_date", None),
            SlotSet("chosen_slot", None),
            SlotSet("booking_confirmed", False),
            SlotSet("booking_id", None),
            SlotSet("problem", None),
            SlotSet("selection_in_progress", False),
            SlotSet("awaiting_slot_selection", False)
        ]
    
    def load_city_proximity(self):
        """Load or create city proximity graph"""
        try:
            # Try to import directly from map.py
            file_dir = os.path.dirname(os.path.abspath(__file__))
            csv_path = os.path.join(file_dir, "datamap", "daerah-working-set.csv")
            
            # Load the CSV file
            if os.path.exists(csv_path):
                df = pd.read_csv(csv_path)
                
                # Build graph
                city_graph = {}
                radius_km = 50  # Define your radius for 'nearby'

                for i, row in df.iterrows():
                    city = row['Town'].lower() if 'Town' in df.columns else None
                    if not city:
                        continue
                        
                    lat1 = row['Lat'] if 'Lat' in df.columns else None
                    lon1 = row['Lon'] if 'Lon' in df.columns else None
                    
                    if not lat1 or not lon1:
                        continue
                        
                    city_graph[city] = {}

                    for j, other in df.iterrows():
                        if i == j:
                            continue
                        other_city = other['Town'].lower() if 'Town' in df.columns else None
                        if not other_city:
                            continue
                            
                        lat2 = other['Lat'] if 'Lat' in df.columns else None
                        lon2 = other['Lon'] if 'Lon' in df.columns else None
                        
                        if not lat2 or not lon2:
                            continue
                            
                        distance = self.haversine(lat1, lon1, lat2, lon2)
                        if distance <= radius_km:
                            city_graph[city][other_city] = round(distance, 2)
                
                print(f"Loaded city proximity data for {len(city_graph)} cities")
                return city_graph
            else:
                print(f"City data file not found at {csv_path}")
                return {}
        except Exception as e:
            print(f"Error loading city proximity data: {e}")
            return {}
    
    def _add_handyman_with_city_distance(self, h_data, user_city, nearby_handymen, other_handymen):
        """Helper method to add handyman with city-based distance calculation"""
        handyman_city = h_data.get("city", "").lower() if h_data.get("city") else ""
        if not user_city or not handyman_city:
            # If we don't have city information, add to other_handymen
            other_handymen.append(h_data)
            return
            
        # Check exact city match first
        if handyman_city == user_city.lower():
            h_data["distance"] = 0  # Same city, assume very close
            nearby_handymen.append(h_data)
            return
            
        # Try the city graph
        try:
            if self.is_nearby_city(city_map.city_graph, user_city):
                h_data["distance"] = self.get_distance(city_map.city_graph, user_city)
                nearby_handymen.append(h_data)
                return
        except Exception as e:
            print(f"Error checking city proximity: {e}")
            
        # If all checks fail, calculate an approximate distance based on Selangor/KL region average
        # This ensures we still consider handymen without exact matches but in general area
        nearby_cities = self._check_general_area_proximity(user_city, handyman_city)
        if nearby_cities:
            h_data["distance"] = 30  # Assume ~30km if in general KL/Selangor area but exact distance unknown
            nearby_handymen.append(h_data)
        else:
            # Not in nearby area, add to other_handymen
            other_handymen.append(h_data)
            
    def _check_general_area_proximity(self, city1, city2):
        """Check if two cities are in the same general metropolitan area"""
        # Define KL/Selangor area cities
        kl_selangor_cities = [
            'kuala lumpur', 'petaling jaya', 'shah alam', 'subang jaya', 'klang',
            'ampang', 'cheras', 'puchong', 'kajang', 'seri kembangan', 'cyberjaya',
            'putrajaya', 'bangi', 'rawang', 'sentul', 'mont kiara', 'bangsar',
            'damansara', 'gombak', 'kepong', 'setapak'
        ]
        
        # Check if both cities are in the KL/Selangor area
        return (city1.lower() in kl_selangor_cities and 
                city2.lower() in kl_selangor_cities)

    def haversine(self, lat1, lon1, lat2, lon2):
        """Calculate the great circle distance between two points in kilometers"""
        # Convert to radians
        lat1, lon1, lat2, lon2 = map(radians, [lat1, lon1, lat2, lon2])
        # Haversine calculation
        dlon = lon2 - lon1 
        dlat = lat2 - lat1 
        a = sin(dlat/2)**2 + cos(lat1) * cos(lat2) * sin(dlon/2)**2
        c = 2 * asin(sqrt(a)) 
        km = 6371 * c  # Earth radius in kilometers
        return km





