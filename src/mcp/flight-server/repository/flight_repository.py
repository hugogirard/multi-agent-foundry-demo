from models import Flight
from azure.cosmos.aio import ContainerProxy
from typing import List

class FlightRepository:
    def __init__(self,container: ContainerProxy):
        self._container = container

    async def get_all_flights(self) -> List[Flight]:
        flights = []
        query = "SELECT * FROM c"
        async for item in self._container.query_items(query=query):
            session = Flight.model_validate(item)
            flights.append(session)
        return flights     
        
    # async def get_flights_by_country(self) -> list[FlightsByCountry]:
    #     pass

    # async def find_by_destination_country(self, destination_country: str) -> FlightList:
    #     pass

    # async def find_by_city(self, origin_city: str, destination_city: str) -> FlightList:
    #     pass