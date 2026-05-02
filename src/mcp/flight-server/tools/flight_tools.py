from fastmcp import FastMCP
from repository.flight_repository import FlightRepository
from models import FlightList, FlightsByCountry

flight_mcp = FastMCP("Flight Tools")

flight_repository = FlightRepository()


@flight_mcp.tool(output_schema=FlightList.model_json_schema())
async def get_all_flights():
    """Retrieve all available flights. Returns the complete list of flights
       with details including airline, origin, destination, times, price,
       and available seats."""
    return await flight_repository.get_all_flights()


@flight_mcp.tool(output_schema=FlightsByCountry.model_json_schema())
async def get_flights_by_country():
    """Retrieve all flights grouped by destination country.
       Returns flights organized by their destination country
       (France, United Kingdom, Italy, Germany, Switzerland, Spain, Netherlands, Portugal)."""
    return await flight_repository.get_flights_by_country()


@flight_mcp.tool(output_schema=FlightList.model_json_schema())
async def find_by_destination_country(destination_country: str):
    """Search for flights by destination country. Returns all flights going to
       the specified country.

    Args:
        destination_country: The destination country name (e.g. France, United Kingdom, Italy, Germany, Switzerland, Spain, Netherlands, Portugal).
    """
    return await flight_repository.find_by_destination_country(destination_country)


@flight_mcp.tool(output_schema=FlightList.model_json_schema())
async def find_by_city(origin_city: str, destination_city: str):
    """Search for flights by origin and destination city.

    Args:
        origin_city: The departure city (Montreal or Toronto).
        destination_city: The arrival city (Paris, London, Rome, Frankfurt, Zurich, Barcelona, Amsterdam, or Lisbon).
    """
    return await flight_repository.find_by_city(origin_city, destination_city)
