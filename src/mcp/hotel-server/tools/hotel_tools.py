from fastmcp import FastMCP
from fastmcp.dependencies import Depends
from repository import HotelRepository
from dependencies import get_hotel_repository
from models import Hotel, HotelList
from typing import List

hotel_mcp = FastMCP("Hotel Tools",
                    instructions="""You are a hotel search assistant. Use these tools to find and retrieve
                                    available hotels. You can list all hotels, search by city, or search
                                    by country. Use get_all_hotels only when no filters are specified.""")

@hotel_mcp.tool(output_schema=HotelList.model_json_schema())
async def get_all_hotels(repository: HotelRepository = Depends(get_hotel_repository)) -> HotelList:
    """Retrieve the complete list of all available hotels.
       Use this only when no filtering criteria (city or country) is specified.
       Returns hotel details including name, city, country, star rating, price per night,
       amenities, and room type."""
    hotels = await repository.get_all_hotels()
    return HotelList(hotels=hotels)


@hotel_mcp.tool(output_schema=HotelList.model_json_schema())
async def get_hotels_by_city(city: str, repository: HotelRepository = Depends(get_hotel_repository)) -> HotelList:
    """Search for hotels in a specific city.
       Use this when the user wants hotels in a particular city (e.g. "hotels in Paris").

    Args:
        city: The city name to search for hotels in (e.g. "Paris", "London", "Rome").
    """
    hotels = await repository.get_hotels_by_city(city=city)
    return HotelList(hotels=hotels)


@hotel_mcp.tool(output_schema=HotelList.model_json_schema())
async def get_hotels_by_country(country: str, repository: HotelRepository = Depends(get_hotel_repository)) -> HotelList:
    """Search for hotels in a specific country.
       Use this when the user wants hotels in a particular country (e.g. "hotels in France").

    Args:
        country: The country name to search for hotels in (e.g. "France", "Italy", "Canada").
    """
    hotels = await repository.get_hotels_by_country(country=country)
    return HotelList(hotels=hotels)