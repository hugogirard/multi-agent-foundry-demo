from pydantic import BaseModel
from .hotel import Hotel
from typing import List

class HotelList(BaseModel):
    hotels: List[Hotel]
