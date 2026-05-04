from contextlib import asynccontextmanager
from repository import FlightRepository
from azure.cosmos.aio import CosmosClient
from config import Config

client = CosmosClient.from_connection_string(Config.cosmos_db_cnx_string())
db = client.get_database_client(Config.cosmos_db())
container_flight = db.get_container_client(Config.flight_container())

@asynccontextmanager
async def get_flight_repository():
    flight_repository = FlightRepository(container=container_flight)
    try:
        yield flight_repository
    finally:
        pass