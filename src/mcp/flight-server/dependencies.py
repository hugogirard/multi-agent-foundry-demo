from contextlib import asynccontextmanager
from repository import FlightRepository

@asynccontextmanager
async def get_flight_repository():
    flight_repository = FlightRepository()
    try:
        return flight_repository
    finally:
        pass