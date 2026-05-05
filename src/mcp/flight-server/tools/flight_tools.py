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
async def get_flight_by_id(flight_id: str, repository:FlightRepository = Depends(get_flight_repository)) -> Optional[Flight]:
    """Retrieve a single flight by its unique flight ID.
       Use this to get full details of a specific flight after search results have been presented,
       or before making a reservation.

    Args:
        flight_id: The unique flight identifier (e.g. "FL-001", "FL-012").
    """
    return await repository.get_flight_by_id(flight_id)


@flight_mcp.tool()
async def search_flights(
    origin_city: Optional[str] = None,
    destination_city: Optional[str] = None,
    origin_country: Optional[str] = None,
    destination_country: Optional[str] = None,
    max_price: Optional[float] = None,
    cabin_class: Optional[str] = None,
    max_stops: Optional[int] = None,
    min_available_seats: Optional[int] = None,
    repository: FlightRepository = Depends(get_flight_repository)
) -> List[Flight]:
    """Search for flights using any combination of filters. All parameters are optional
       but at least one should be provided. All filters are combined with AND logic.
       This is the preferred tool for complex queries like "direct economy flights from
       Montreal to Paris under $700 with at least 2 seats available".

    Args:
        origin_city: Filter by departure city (e.g. "Montreal", "Toronto").
        destination_city: Filter by arrival city (e.g. "Paris", "London", "Rome").
        origin_country: Filter by country of departure (e.g. "Canada").
        destination_country: Filter by destination country (e.g. "France", "Italy").
        max_price: Maximum price per person in CAD (e.g. 700.0).
        cabin_class: Filter by cabin class (e.g. "economy", "premium_economy").
        max_stops: Maximum number of stops (0 for direct flights only).
        min_available_seats: Minimum number of seats that must be available.
    """
    if not any([origin_city, destination_city, origin_country, destination_country,
                max_price is not None, cabin_class, max_stops is not None, min_available_seats is not None]):
        raise ValueError("At least one search filter must be provided. Use get_all_flights for unfiltered results.")
    return await repository.search_flights(
        origin_city=origin_city,
        destination_city=destination_city,
        origin_country=origin_country,
        destination_country=destination_country,
        max_price=max_price,
        cabin_class=cabin_class,
        max_stops=max_stops,
        min_available_seats=min_available_seats,
    )


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
       If both are provided, returns flights from origin_city TO destination_city.

    Args:
        origin_city: The departure city (optional).
        destination_city: The arrival city (optional).
    """
    if not origin_city and not destination_city:
        raise ValueError("At least one of origin_city or destination_city must be provided.")
    return await repository.find_by_city(origin_city, destination_city)
