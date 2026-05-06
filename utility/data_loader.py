from azure.cosmos import CosmosClient
from dotenv import load_dotenv
from datetime import datetime, timedelta, timezone
import os
import json
import uuid

load_dotenv(override=True)

COSMOS_DB_CONNECTION_STRING = os.getenv('CosmosDbConnectionString')
DATABASE_NAME = 'ContosoAgency'
FLIGHT_CONTAINER = 'flight'

DATE_FORMAT = "%Y-%m-%dT%H:%M:%SZ"


def shift_dates(flights):
    """Shift all flight dates so the earliest departure is 3 weeks from today."""
    # Find the earliest departure date across all flights
    earliest = None
    for flight in flights:
        dt = datetime.strptime(flight["departureTime"], DATE_FORMAT)
        if earliest is None or dt < earliest:
            earliest = dt

    # Calculate the offset: 3 weeks from today minus the earliest departure
    today = datetime.now(timezone.utc).replace(hour=0, minute=0, second=0, microsecond=0, tzinfo=None)
    target_start = today + timedelta(weeks=3)
    offset = target_start - earliest

    print(f"  Shifting all dates by {offset.days} days (earliest departure becomes {target_start.strftime('%Y-%m-%d')})")

    # Apply offset to all date fields
    date_fields = ["departureTime", "arrivalTime"]
    for flight in flights:
        for field in date_fields:
            dt = datetime.strptime(flight[field], DATE_FORMAT)
            flight[field] = (dt + offset).strftime(DATE_FORMAT)
        if "returnFlight" in flight:
            for field in ["departureTime", "arrivalTime"]:
                dt = datetime.strptime(flight["returnFlight"][field], DATE_FORMAT)
                flight["returnFlight"][field] = (dt + offset).strftime(DATE_FORMAT)

    return flights


client = CosmosClient.from_connection_string(COSMOS_DB_CONNECTION_STRING)

db = client.get_database_client(DATABASE_NAME)

container = db.get_container_client(FLIGHT_CONTAINER)

# Delete all existing items in the container
# this can be mostly done if the azd up is execute more than once
for item in container.read_all_items():
    container.delete_item(item=item['id'], partition_key=item['originCountry'])

script_dir = os.path.dirname(os.path.abspath(__file__))
with open(os.path.join(script_dir, '..', 'data', 'flights.json'), 'r') as f:
    flights = json.load(f)["flights"]

flights = shift_dates(flights)

for flight in flights:
   flight['id'] = str(uuid.uuid4())
   container.create_item(body=flight)

