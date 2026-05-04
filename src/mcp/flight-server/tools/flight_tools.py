from fastmcp import FastMCP
from fastmcp.dependencies import Depends
from repository import FlightRepository
from dependencies import get_flight_repository
from models import Flight
from typing import List, Optional

flight_mcp = FastMCP("Flight Tools")

@flight_mcp.tool()
async def get_all_flights(repository:FlightRepository = Depends(get_flight_repository)) -> List[Flight]:
    """Retrieve the complete list of all available flights.
       Use this only when no filtering criteria (city or country) is specified.
       Returns flight details including airline, origin, destination, times, price,
       and available seats."""
    return await repository.get_all_flights()


@flight_mcp.tool()
async def get_flights_by_country(country:str,repository:FlightRepository = Depends(get_flight_repository)) -> List[Flight]:
    """Search for flights departing from a specific country of origin.
       Use this when the user wants flights leaving from a country (e.g. "flights from Canada").

       Args:
          country: The country of origin where the flight departs from (e.g. Canada, France, Italy).
    """
    return await repository.get_flights_by_origin_country(country=country)


@flight_mcp.tool()
async def find_by_destination_country(destination_country: str,repository:FlightRepository = Depends(get_flight_repository)) -> List[Flight]:
    """Search for flights arriving in a specific destination country.
       Use this when the user wants flights going to a country (e.g. "flights to France").

    Args:
        destination_country: The destination country name (e.g. Canada, France, Italy).
    """
    return await repository.find_by_destination_country(destination_country)


@flight_mcp.tool()
async def find_by_city(origin_city: Optional[str] = None, destination_city: Optional[str] = None,repository:FlightRepository = Depends(get_flight_repository)) -> List[Flight]:
    """Search for flights by origin city, destination city, or both.
       At least one of origin_city or destination_city must be provided.
       If only origin_city is provided, returns all flights departing from that city.
       If only destination_city is provided, returns all flights arriving at that city.
       If both are provided, returns flights matching either city.

    Args:
        origin_city: The departure city (optional).
        destination_city: The arrival city (optional).
    """
    if not origin_city and not destination_city:
        raise ValueError("At least one of origin_city or destination_city must be provided.")
    return await repository.find_by_city(origin_city, destination_city)
