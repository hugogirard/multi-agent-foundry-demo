from pydantic import BaseModel


class Reservation(BaseModel):
    reservation_id: str
    flight_id: str
    flight_number: str
    passengers: int
    total_price: float
    status: str
