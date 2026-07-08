from azure.cosmos.aio import ContainerProxy
from models import Hotel
from typing import List, Optional

class HotelRepository:

    def __init__(self, container:ContainerProxy):
        self._container = container

    async def get_all_hotels(self) -> List[Hotel]:
        return await self._run_query("SELECT * FROM c")

    async def get_hotels_by_city(self, city: str) -> List[Hotel]:
        return await self._run_query("SELECT * FROM c WHERE c.city = @city", [{"name": "@city", "value": city}])

    async def get_hotels_by_country(self, country: str) -> List[Hotel]:
        return await self._run_query("SELECT * FROM c WHERE c.country = @country", [{"name": "@country", "value": country}])

    async def _run_query(self, query: str, parameters: list[dict[str, object]] | None = None) -> List[Hotel]:
        hotels = []
        async for item in self._container.query_items(query=query, parameters=parameters):
            hotel = Hotel.model_validate(item)
            hotels.append(hotel)
        return hotels

    