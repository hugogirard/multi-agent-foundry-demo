from pydantic import BaseModel, Field
from typing import Optional


class SearchParameters(BaseModel):
    origin_city: Optional[str] = Field(default=None, alias="originCity")
    destination_city: Optional[str] = Field(default=None, alias="destinationCity")
    origin_country: Optional[str] = Field(default=None, alias="originCountry")
    destination_country: Optional[str] = Field(default=None, alias="destinationCountry")
    max_price: Optional[float] = Field(default=None, alias="maxPrice")
    cabin_class: Optional[str] = Field(default=None, alias="cabinClass")
    max_stops: Optional[int] = Field(default=None, alias="maxStops")
    min_available_seats: Optional[int] = Field(default=None, alias="minAvailableSeats")

    model_config = {"populate_by_name": True}
