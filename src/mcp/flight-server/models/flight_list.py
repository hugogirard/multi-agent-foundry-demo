from pydantic import BaseModel
from models.flight_summary import FlightSummary


class FlightList(BaseModel):
    flights: list[FlightSummary]
