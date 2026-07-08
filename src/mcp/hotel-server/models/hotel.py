from pydantic import BaseModel, Field


class Hotel(BaseModel):    
    id: str
    hotel_id: str = Field(alias="hotelId")
    name: str
    city: str
    country: str
    star_rating: int = Field(alias="starRating")
    neighborhood: str
    address: str
    price_per_night: float = Field(alias="pricePerNight")
    guest_rating: float = Field(alias="guestRating")
    amenities: list[str]
    room_type: str = Field(alias="roomType")
    cancellation_policy: str = Field(alias="cancellationPolicy")
    distance_to_center_km: float = Field(alias="distanceToCenterKm")

    model_config = {"populate_by_name": True}
