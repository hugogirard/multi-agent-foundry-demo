from contextlib import asynccontextmanager
from azure.cosmos.aio import CosmosClient
from repository import HotelRepository
from config import Config

client = CosmosClient.from_connection_string(Config.cosmos_db_cnx_string())
db = client.get_database_client(Config.cosmos_db())
container_hotel = db.get_container_client(Config.hotel_container())

@asynccontextmanager
async def get_hotel_repository():    
    hotel_repository = HotelRepository(container=container_hotel)
    try:
        yield hotel_repository
    finally:
        pass