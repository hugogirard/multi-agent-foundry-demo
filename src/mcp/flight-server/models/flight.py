from pydantic import BaseModel, Field
from models.return_flight import ReturnFlight


class Flight(BaseModel):
    id: str
    flight_id: str = Field(alias="flightId")
    airline: str
    flight_number: str = Field(alias="flightNumber")
    origin: str
    origin_city: str = Field(alias="originCity")
    origin_airport: str = Field(alias="originAirport")
    origin_country: str = Field(alias="originCountry")
    destination: str
    destination_city: str = Field(alias="destinationCity")
    destination_airport: str = Field(alias="destinationAirport")
    destination_country: str = Field(alias="destinationCountry")
    departure_time: str = Field(alias="departureTime")
    arrival_time: str = Field(alias="arrivalTime")
    duration_hours: float = Field(alias="durationHours")
    stops: int
    price_per_person: float = Field(alias="pricePerPerson")
    cabin_class: str = Field(alias="cabinClass")
    available_seats: int = Field(alias="availableSeats")
    return_flight: ReturnFlight = Field(alias="returnFlight")

    model_config = {"populate_by_name": True}
