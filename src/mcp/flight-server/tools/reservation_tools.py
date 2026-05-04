# from fastmcp import FastMCP
# from repository.flight_repository import FlightRepository
# from models import Reservation

# reservation_mcp = FastMCP("Reservation Tools")

# flight_repository = FlightRepository()


# @reservation_mcp.tool(output_schema=Reservation.model_json_schema())
# async def reserve(flight_id: str, passengers: int):
#     """Reserve seats on a specific flight. Requires the flight_id and number of passengers. Fails if not enough seats are available."""
#     return await flight_repository.reserve(flight_id, passengers)


# @reservation_mcp.tool(output_schema=Reservation.model_json_schema())
# async def cancel(reservation_id: str):
#     """Cancel an existing flight reservation using the reservation ID. Releases the reserved seats back to availability."""
#     return await flight_repository.cancel(reservation_id)
