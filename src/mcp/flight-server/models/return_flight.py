from pydantic import BaseModel, Field


class ReturnFlight(BaseModel):
    flight_number: str = Field(alias="flightNumber")
    departure_time: str = Field(alias="departureTime")
    arrival_time: str = Field(alias="arrivalTime")
    duration_hours: float = Field(alias="durationHours")

    model_config = {"populate_by_name": True}
