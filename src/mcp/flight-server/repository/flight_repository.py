import json
import uuid
from pathlib import Path
from itertools import groupby
from operator import itemgetter

from models import FlightSummary, FlightList, Reservation, FlightsByCountry

DATA_PATH = Path(__file__).parent.parent / "data" / "flight.json"


class FlightRepository:
    def __init__(self):
        self._reservations: dict[str, Reservation] = {}

    def _load_flights(self) -> list[dict]:
        with open(DATA_PATH, "r", encoding="utf-8") as f:
            data = json.load(f)
        return data["flights"]

    async def get_all_flights(self) -> FlightList:
        raw = self._load_flights()
        return FlightList(flights=[FlightSummary(**f) for f in raw])

    async def get_flights_by_country(self) -> list[FlightsByCountry]:
        raw = sorted(self._load_flights(), key=itemgetter("destination_country"))
        result = []
        for country, group in groupby(raw, key=itemgetter("destination_country")):
            result.append(FlightsByCountry(country=country, flights=[FlightSummary(**f) for f in group]))
        return result

    async def find_by_destination_country(self, destination_country: str) -> FlightList:
        raw = self._load_flights()
        return FlightList(flights=[FlightSummary(**f) for f in raw if f["destination_country"].lower() == destination_country.lower()])

    async def find_by_city(self, origin_city: str, destination_city: str) -> FlightList:
        raw = self._load_flights()
        return FlightList(flights=[
            FlightSummary(**f) for f in raw
            if f["origin_city"].lower() == origin_city.lower()
            and f["destination_city"].lower() == destination_city.lower()
        ])

    async def reserve(self, flight_id: str, passengers: int) -> Reservation:
        raw = self._load_flights()
        flight = next((f for f in raw if f["flight_id"] == flight_id), None)
        if flight is None:
            raise ValueError(f"Flight {flight_id} not found.")
        if flight["available_seats"] < passengers:
            raise ValueError(f"Not enough seats. Available: {flight['available_seats']}, requested: {passengers}.")

        reservation_id = f"RES-{uuid.uuid4().hex[:8].upper()}"
        reservation = Reservation(
            reservation_id=reservation_id,
            flight_id=flight_id,
            flight_number=flight["flight_number"],
            passengers=passengers,
            total_price=flight["price_per_person"] * passengers,
            status="confirmed",
        )
        self._reservations[reservation_id] = reservation
        return reservation

    async def cancel(self, reservation_id: str) -> Reservation:
        reservation = self._reservations.get(reservation_id)
        if reservation is None:
            raise ValueError(f"Reservation {reservation_id} not found.")
        reservation.status = "cancelled"
        return reservation
