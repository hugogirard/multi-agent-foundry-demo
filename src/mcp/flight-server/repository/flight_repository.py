from models import Flight
from azure.cosmos.aio import ContainerProxy
from typing import List

class FlightRepository:
    def __init__(self,container: ContainerProxy):
        self._container = container

    async def get_all_flights(self) -> List[Flight]:                
        return await self._run_query("SELECT * FROM c")  
        
    async def get_flights_by_origin_country(self,country:str) -> List[Flight]:
        return await self._run_query("SELECT * FROM c WHERE c.originCountry = @country",[{"name": "@country", "value": country}])

    async def find_by_destination_country(self, country: str) -> List[Flight]:
        return await self._run_query("SELECT * FROM c WHERE c.originCountry = @country",[{"name": "@country", "value": country}])

    async def find_by_city(self, origin_city: str | None = None, destination_city: str | None = None) -> List[Flight]:
        if origin_city and destination_city:
            return await self._run_query(
                "SELECT * FROM c WHERE c.originCity = @originCity OR c.destinationCity = @destinationCity",
                [{"name": "@originCity", "value": origin_city}, {"name": "@destinationCity", "value": destination_city}]
            )
        elif origin_city:
            return await self._run_query(
                "SELECT * FROM c WHERE c.originCity = @originCity",
                [{"name": "@originCity", "value": origin_city}]
            )
        else:
            return await self._run_query(
                "SELECT * FROM c WHERE c.destinationCity = @destinationCity",
                [{"name": "@destinationCity", "value": destination_city}]
            )

    async def _run_query(self,query:str,parameters:list[dict[str,object]] | None = None) -> List[Flight]:
        flights = []        
        async for item in self._container.query_items(query=query):
            session = Flight.model_validate(item)
            flights.append(session)
        return flights     
                