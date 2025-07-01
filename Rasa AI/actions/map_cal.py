import pandas as pd
from math import radians, cos, sin, asin, sqrt
import os

# Get the directory where this script is located
script_dir = os.path.dirname(os.path.abspath(__file__))
# Build path to CSV file
csv_path = os.path.join(script_dir, "datamap", "daerah-working-set.csv")

# Load CSV file using absolute path
df = pd.read_csv(csv_path, encoding='latin1')

# Convert 'Lat' and 'Lon' columns to float
df['Lat'] = pd.to_numeric(df['Lat'], errors='coerce')
df['Lon'] = pd.to_numeric(df['Lon'], errors='coerce')

# Drop any rows with NaN values in Lat or Lon
df = df.dropna(subset=['Lat', 'Lon'])

def haversine(lat1, lon1, lat2, lon2):
    # Ensure all inputs are float
    lat1, lon1, lat2, lon2 = float(lat1), float(lon1), float(lat2), float(lon2)
    
    # Convert to radians
    lon1, lat1, lon2, lat2 = map(radians, [lon1, lat1, lon2, lat2])
    # Haversine calculation
    dlon = lon2 - lon1 
    dlat = lat2 - lat1 
    a = sin(dlat/2)**2 + cos(lat1) * cos(lat2) * sin(dlon/2)**2
    c = 2 * asin(sqrt(a)) 
    km = 6371 * c
    return km

# Build graph
city_graph = {}
radius_km = 50  # Define your radius for 'nearby'

# Print some debug info about the data
print(f"Building city graph with {len(df)} cities")

for i, row in df.iterrows():
    city = row['Town'].lower()  # Convert to lowercase for consistency
    lat1 = row['Lat']
    lon1 = row['Lon']
    city_graph[city] = {}

    for j, other in df.iterrows():
        if i == j:
            continue
        other_city = other['Town'].lower()
        lat2 = other['Lat']
        lon2 = other['Lon']
        try:
            distance = haversine(lat1, lon1, lat2, lon2)
            if distance <= radius_km:
                city_graph[city][other_city] = round(distance, 2)
                # Debug for specific cities of interest
                if (city == 'petaling jaya' and other_city == 'mont kiara') or \
                   (city == 'mont kiara' and other_city == 'petaling jaya') or \
                   (city == 'petaling jaya' and other_city == 'shah alam') or \
                   (city == 'shah alam' and other_city == 'petaling jaya'):
                    print(f"Distance from {city} to {other_city}: {round(distance, 2)} km")
        except (ValueError, TypeError) as e:
            print(f"Error calculating distance: {e}, skipping {city} to {other_city}")

# Print counts of nearby cities for key locations
for city in ['petaling jaya', 'mont kiara', 'shah alam']:
    if city in city_graph:
        print(f"{city.title()} has {len(city_graph[city])} nearby cities within {radius_km} km")
        

# Now city_graph is ready to be used in your Rasa action

def get_nearby_cities(city_name, max_distance=50):
    """Get nearby cities within max_distance km"""
    city_name = city_name.lower()  # Convert to lowercase for consistency
    if city_name not in city_graph:
        return []
    
    nearby = []
    for other_city, distance in city_graph[city_name].items():
        if distance <= max_distance:
            nearby.append((other_city, distance))
    
    # Sort by distance
    nearby.sort(key=lambda x: x[1])
    return nearby