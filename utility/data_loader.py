from azure.cosmos import CosmosClient
from dotenv import load_dotenv
import os
import json
import uuid

load_dotenv(override=True)

COSMOS_DB_CONNECTION_STRING = os.getenv('CosmosDbConnectionString')
DATABASE_NAME = 'ContosoAgency'
FLIGHT_CONTAINER = 'flight'

client = CosmosClient.from_connection_string(COSMOS_DB_CONNECTION_STRING)

db = client.get_database_client(DATABASE_NAME)

container = db.get_container_client(FLIGHT_CONTAINER)

script_dir = os.path.dirname(os.path.abspath(__file__))
with open(os.path.join(script_dir, '..', 'data', 'flights.json'), 'r') as f:
    flights = json.load(f)["flights"]

for flight in flights:
   flight['id'] = str(uuid.uuid4())
   container.create_item(body=flight)

