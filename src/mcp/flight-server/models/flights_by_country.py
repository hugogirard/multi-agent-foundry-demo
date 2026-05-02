from pydantic import BaseModel
from models.flight_summary import FlightSummary


class FlightsByCountry(BaseModel):
    country: str
    flights: list[FlightSummary]
