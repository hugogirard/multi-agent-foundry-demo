from models import Flight
from azure.cosmos.aio import ContainerProxy
from typing import List, Optional

class FlightRepository:
    def __init__(self,container: ContainerProxy):
        self._container = container

    async def get_all_flights(self) -> List[Flight]:                
        return await self._run_query("SELECT * FROM c")  
        
    async def get_flights_by_origin_country(self,country:str) -> List[Flight]:
        return await self._run_query("SELECT * FROM c WHERE c.originCountry = @country",[{"name": "@country", "value": country}])

    async def find_by_destination_country(self, country: str) -> List[Flight]:
        return await self._run_query("SELECT * FROM c WHERE c.destinationCountry = @country",[{"name": "@country", "value": country}])

    async def get_flight_by_id(self, flight_id: str) -> Optional[Flight]:
        results = await self._run_query(
            "SELECT * FROM c WHERE c.flightId = @flightId",
            [{"name": "@flightId", "value": flight_id}]
        )
        return results[0] if results else None

    async def find_by_city(self, origin_city: str | None = None, destination_city: str | None = None) -> List[Flight]:
        if origin_city and destination_city:
            return await self._run_query(
                "SELECT * FROM c WHERE c.originCity = @originCity AND c.destinationCity = @destinationCity",
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

    async def search_flights(
        self,
        origin_city: Optional[str] = None,
        destination_city: Optional[str] = None,
        origin_country: Optional[str] = None,
        destination_country: Optional[str] = None,
        max_price: Optional[float] = None,
        cabin_class: Optional[str] = None,
        max_stops: Optional[int] = None,
        min_available_seats: Optional[int] = None,
    ) -> List[Flight]:
        conditions = []
        parameters = []

        if origin_city:
            conditions.append("c.originCity = @originCity")
            parameters.append({"name": "@originCity", "value": origin_city})
        if destination_city:
            conditions.append("c.destinationCity = @destinationCity")
            parameters.append({"name": "@destinationCity", "value": destination_city})
        if origin_country:
            conditions.append("c.originCountry = @originCountry")
            parameters.append({"name": "@originCountry", "value": origin_country})
        if destination_country:
            conditions.append("c.destinationCountry = @destinationCountry")
            parameters.append({"name": "@destinationCountry", "value": destination_country})
        if max_price is not None:
            conditions.append("c.pricePerPerson <= @maxPrice")
            parameters.append({"name": "@maxPrice", "value": max_price})
        if cabin_class:
            conditions.append("c.cabinClass = @cabinClass")
            parameters.append({"name": "@cabinClass", "value": cabin_class})
        if max_stops is not None:
            conditions.append("c.stops <= @maxStops")
            parameters.append({"name": "@maxStops", "value": max_stops})
        if min_available_seats is not None:
            conditions.append("c.availableSeats >= @minSeats")
            parameters.append({"name": "@minSeats", "value": min_available_seats})

        query = "SELECT * FROM c"
        if conditions:
            query += " WHERE " + " AND ".join(conditions)

        return await self._run_query(query, parameters if parameters else None)

    async def _run_query(self,query:str,parameters:list[dict[str,object]] | None = None) -> List[Flight]:
        flights = []        
        async for item in self._container.query_items(query=query):
            session = Flight.model_validate(item)
            flights.append(session)
        return flights     
                