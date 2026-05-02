from pydantic import BaseModel
from models.return_flight import ReturnFlight


class Flight(BaseModel):
    flight_id: str
    airline: str
    flight_number: str
    origin: str
    origin_city: str
    origin_airport: str
    origin_country: str
    destination: str
    destination_city: str
    destination_airport: str
    destination_country: str
    departure_time: str
    arrival_time: str
    duration_hours: float
    stops: int
    price_per_person: float
    cabin_class: str
    available_seats: int
    return_flight: ReturnFlight
