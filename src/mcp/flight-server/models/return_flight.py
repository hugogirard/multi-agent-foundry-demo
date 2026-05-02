from pydantic import BaseModel


class ReturnFlight(BaseModel):
    flight_number: str
    departure_time: str
    arrival_time: str
    duration_hours: float
