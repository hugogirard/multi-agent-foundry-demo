from pydantic import BaseModel
from .flight import Flight
from typing import List

class FlightList(BaseModel):
    flights: List[Flight]