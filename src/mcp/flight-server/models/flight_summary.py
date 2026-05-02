from pydantic import BaseModel


class FlightSummary(BaseModel):
    flight_id: str
    airline: str
    flight_number: str
    origin_city: str
    destination_city: str
    departure_time: str
    arrival_time: str
    duration_hours: float
    stops: int
    price_per_person: float
    cabin_class: str
    available_seats: int
