"""
Contoso Travel Agency - PDF Document Generator

Generates branded PDF documents for Foundry IQ grounding:
  - Loyalty program tier benefits (Silver, Gold, Platinum)
  - Cancellation policies by category (Flights, Hotels, Activities)
"""

import os
from pathlib import Path
from fpdf import FPDF


# ────────────────────────────────────────────────────────────────────
# Paths
# ────────────────────────────────────────────────────────────────────
ROOT_DIR = Path(__file__).resolve().parent.parent
LOYALTY_DIR = ROOT_DIR / "documents" / "loyalty-program"
CANCELLATION_DIR = ROOT_DIR / "documents" / "cancellation-policies"

# ────────────────────────────────────────────────────────────────────
# Branding constants
# ────────────────────────────────────────────────────────────────────
BRAND_DARK = (0, 51, 102)       # #003366
BRAND_ACCENT = (0, 102, 204)    # #0066CC
BRAND_LIGHT_BG = (230, 240, 250)
BLACK = (0, 0, 0)
GRAY = (100, 100, 100)
WHITE = (255, 255, 255)


class ContosoPDF(FPDF):
    """Branded PDF with Contoso Travel Agency header/footer."""

    def __init__(self, title: str):
        super().__init__()
        self.doc_title = title
        self.set_auto_page_break(auto=True, margin=25)

    # ── Header ──────────────────────────────────────────────────────
    def header(self):
        # Blue bar
        self.set_fill_color(*BRAND_DARK)
        self.rect(0, 0, 210, 28, "F")

        # Agency name
        self.set_font("Helvetica", "B", 16)
        self.set_text_color(*WHITE)
        self.set_xy(10, 5)
        self.cell(0, 8, "Contoso Travel Agency", new_x="LMARGIN", new_y="NEXT")

        # Tagline
        self.set_font("Helvetica", "I", 9)
        self.set_text_color(180, 210, 240)
        self.set_x(10)
        self.cell(0, 5, "Your journey begins with us  |  Est. 2005", new_x="LMARGIN", new_y="NEXT")

        # Document title on accent bar
        self.set_fill_color(*BRAND_ACCENT)
        self.rect(0, 28, 210, 10, "F")
        self.set_font("Helvetica", "B", 10)
        self.set_text_color(*WHITE)
        self.set_xy(10, 29)
        self.cell(0, 8, self.doc_title)

        self.ln(18)

    # ── Footer ──────────────────────────────────────────────────────
    def footer(self):
        self.set_y(-18)
        self.set_draw_color(*BRAND_DARK)
        self.line(10, self.get_y(), 200, self.get_y())
        self.ln(2)
        self.set_font("Helvetica", "I", 7)
        self.set_text_color(*GRAY)
        self.cell(0, 5, "Contoso Travel Agency - Confidential", new_x="LEFT")
        self.cell(0, 5, f"Page {self.page_no()}/{{nb}}", align="R")

    # ── Helpers ─────────────────────────────────────────────────────
    def section_title(self, text: str):
        self.ln(4)
        self.set_font("Helvetica", "B", 13)
        self.set_text_color(*BRAND_DARK)
        self.cell(0, 8, text, new_x="LMARGIN", new_y="NEXT")
        # Underline
        self.set_draw_color(*BRAND_ACCENT)
        self.set_line_width(0.5)
        self.line(10, self.get_y(), 200, self.get_y())
        self.ln(3)

    def subsection_title(self, text: str):
        self.ln(2)
        self.set_font("Helvetica", "B", 11)
        self.set_text_color(*BRAND_ACCENT)
        self.cell(0, 7, text, new_x="LMARGIN", new_y="NEXT")
        self.ln(1)

    def body_text(self, text: str):
        self.set_font("Helvetica", "", 10)
        self.set_text_color(*BLACK)
        self.multi_cell(0, 5.5, text)
        self.ln(1)

    def bullet(self, text: str, indent: int = 15):
        self.set_font("Helvetica", "", 10)
        self.set_text_color(*BLACK)
        x = self.get_x()
        self.set_x(indent)
        self.cell(5, 5.5, "-")  # bullet char
        self.multi_cell(0, 5.5, text)
        self.set_x(x)

    def tier_callout(self, tier_name: str, text: str):
        """Inline callout for a loyalty tier benefit woven into policy text."""
        self.set_font("Helvetica", "B", 10)
        self.set_text_color(*BRAND_ACCENT)
        tier_label = f"{tier_name} Members: "
        self.set_x(15)
        w = self.get_string_width(tier_label)
        self.cell(w, 5.5, tier_label)
        self.set_font("Helvetica", "", 10)
        self.set_text_color(*BLACK)
        self.multi_cell(0, 5.5, text)
        self.ln(0.5)

    def highlight_box(self, text: str):
        self.ln(2)
        self.set_fill_color(*BRAND_LIGHT_BG)
        self.set_font("Helvetica", "I", 9)
        self.set_text_color(*BRAND_DARK)
        y = self.get_y()
        self.set_x(12)
        self.multi_cell(186, 5.5, text, fill=True)
        self.ln(2)

    def save_to(self, path: Path):
        path.parent.mkdir(parents=True, exist_ok=True)
        self.alias_nb_pages()
        self.output(str(path))


# ====================================================================
#  LOYALTY PROGRAM DOCUMENTS
# ====================================================================

TIERS = {
    "Silver": {
        "filename": "contoso-silver-tier-benefits.pdf",
        "title": "Contoso Voyager Rewards - Silver Tier Benefits",
        "subtitle": "Silver Tier",
        "qualification": "Spend $2,000 CAD or more with Contoso Travel Agency within a calendar year, or complete 3 or more bookings.",
        "maintenance": "Maintain Silver status by spending at least $1,500 CAD or completing 2 bookings per calendar year. Status is reviewed annually on January 1st.",
        "points_rate": "1 point per $1 CAD spent",
        "points_redemption": "Redeem points starting at 500 points ($5 CAD value). Points can be applied to any future booking - flights, hotels, or activities. Points expire after 18 months of account inactivity.",
        "flight_benefits": [
            "Priority check-in at airport counters and online (skip standard queues).",
            "1 free checked bag (up to 23 kg) on all Contoso-booked flights.",
            "No change fees for flight modifications made more than 72 hours before departure.",
            "Standard rebooking: $50 CAD rebooking fee applies within the 72-hour window.",
            "Basic travel insurance included at no extra cost (covers trip cancellation up to $1,000 CAD and medical emergencies up to $10,000 CAD).",
        ],
        "hotel_benefits": [
            "5% discount on the nightly rate at all partner hotels booked through Contoso.",
            "Early check-in requests prioritized (subject to hotel availability).",
            "Complimentary Wi-Fi at partner hotels where not already included.",
        ],
        "activity_benefits": [
            "Access to the Contoso curated activities catalog with verified reviews.",
            "5% discount on select Contoso-exclusive experiences.",
            "Priority customer support for activity-related inquiries (response within 12 hours).",
        ],
        "general_benefits": [
            "Dedicated Silver member support line (available Mon-Fri, 8 AM - 8 PM ET).",
            "Monthly newsletter with exclusive Silver-tier travel deals and destination spotlights.",
            "Birthday bonus: 200 bonus points credited to your account each year.",
        ],
    },
    "Gold": {
        "filename": "contoso-gold-tier-benefits.pdf",
        "title": "Contoso Voyager Rewards - Gold Tier Benefits",
        "subtitle": "Gold Tier",
        "qualification": "Spend $5,000 CAD or more with Contoso Travel Agency within a calendar year, or complete 6 or more bookings.",
        "maintenance": "Maintain Gold status by spending at least $4,000 CAD or completing 5 bookings per calendar year. Status is reviewed annually on January 1st. If requirements are not met, members are gracefully downgraded to Silver with a 3-month grace period.",
        "points_rate": "1.5 points per $1 CAD spent",
        "points_redemption": "Redeem points starting at 250 points ($2.50 CAD value). Points can be applied to any future booking - flights, hotels, or activities. Gold members enjoy a 10% bonus when redeeming points for hotel stays. Points expire after 24 months of account inactivity.",
        "flight_benefits": [
            "Priority boarding and priority check-in at airport counters and online.",
            "2 free checked bags (up to 23 kg each) on all Contoso-booked flights.",
            "No change fees for flight modifications made more than 48 hours before departure.",
            "1 complimentary flight rebooking per calendar year (any reason, any timeframe).",
            "Free standard seat selection on all flights (window, aisle, or extra legroom when available).",
            "Airport lounge access: 2 complimentary lounge passes per round trip at participating airports.",
            "Enhanced travel insurance included (covers trip cancellation up to $3,000 CAD, medical emergencies up to $50,000 CAD, and luggage loss up to $1,500 CAD).",
        ],
        "hotel_benefits": [
            "10% discount on the nightly rate at all partner hotels booked through Contoso.",
            "Complimentary room upgrade to the next available category (subject to hotel availability at check-in).",
            "Late checkout until 2 PM at partner hotels (subject to availability).",
            "Complimentary breakfast at select partner hotels.",
            "Guaranteed room availability when booked at least 48 hours in advance (at participating hotels).",
        ],
        "activity_benefits": [
            "10% discount on all activities and experiences booked through Contoso.",
            "Early access to newly listed experiences and seasonal tours (48-hour preview window).",
            "1 complimentary activity upgrade per trip (e.g., group tour to semi-private, standard to premium).",
            "Priority customer support for activity inquiries (response within 4 hours).",
        ],
        "general_benefits": [
            "Dedicated Gold member support line (available 7 days a week, 7 AM - 10 PM ET).",
            "Quarterly travel credit: $25 CAD applied automatically to your next booking each quarter.",
            "Birthday bonus: 500 bonus points credited to your account each year.",
            "Access to Gold-exclusive flash sales and partner promotions.",
            "Complimentary travel planning consultation (one 30-minute session per year with a Contoso travel advisor).",
        ],
    },
    "Platinum": {
        "filename": "contoso-platinum-tier-benefits.pdf",
        "title": "Contoso Voyager Rewards - Platinum Tier Benefits",
        "subtitle": "Platinum Tier",
        "qualification": "Spend $12,000 CAD or more with Contoso Travel Agency within a calendar year, or complete 12 or more bookings.",
        "maintenance": "Maintain Platinum status by spending at least $10,000 CAD or completing 10 bookings per calendar year. Status is reviewed annually on January 1st. If requirements are not met, members retain Platinum benefits for a 6-month grace period before being downgraded to Gold.",
        "points_rate": "2 points per $1 CAD spent",
        "points_redemption": "Redeem points starting at 100 points ($1 CAD value). Points can be applied to any future booking. Platinum members enjoy a 20% bonus when redeeming points for any booking type. Points never expire as long as your Platinum status is active.",
        "flight_benefits": [
            "First priority boarding and check-in across all Contoso-booked flights.",
            "3 free checked bags (up to 32 kg each) on all Contoso-booked flights.",
            "No change fees - ever. Modify your flights at any time before departure at no cost.",
            "Unlimited complimentary flight rebooking (any reason, any timeframe, no fees).",
            "Free premium seat selection on all flights, including extra legroom, bulkhead, and exit row seats.",
            "Complimentary cabin upgrade to the next available class (economy to premium economy, or premium economy to business) when available at departure, on a space-available basis.",
            "Unlimited airport lounge access plus 1 guest at all participating airport lounges worldwide.",
            "Premium travel insurance included (covers trip cancellation up to $10,000 CAD, medical emergencies up to $250,000 CAD, medical evacuation, luggage loss up to $5,000 CAD, and trip interruption up to $5,000 CAD).",
            "Priority refund processing: refunds are processed within 3 business days (standard is 10-15 business days).",
        ],
        "hotel_benefits": [
            "20% discount on the nightly rate at all partner hotels booked through Contoso.",
            "Guaranteed room upgrade to the next available category at check-in.",
            "Late checkout until 4 PM at partner hotels (guaranteed, not subject to availability).",
            "Complimentary breakfast at all partner hotels.",
            "Welcome amenity at partner hotels (fruit basket, wine, or local specialty).",
            "Guaranteed room availability when booked at least 24 hours in advance (at all partner hotels).",
            "Access to exclusive Platinum-only hotel properties and suites in select destinations.",
        ],
        "activity_benefits": [
            "20% discount on all activities and experiences booked through Contoso.",
            "72-hour early access to newly listed experiences and seasonal tours before Gold members.",
            "Complimentary activity upgrades on every booking (group to private, standard to VIP).",
            "Access to Contoso Exclusive Experiences - curated private tours, chef's table dinners, and behind-the-scenes cultural events available only to Platinum members.",
            "Priority rebooking for sold-out activities (Contoso will contact the provider on your behalf).",
            "Dedicated activity concierge for custom itinerary planning.",
        ],
        "general_benefits": [
            "Dedicated Platinum concierge line (available 24/7, 365 days a year).",
            "Monthly travel credit: $50 CAD applied automatically to your next booking each month.",
            "Birthday bonus: 1,000 bonus points plus a surprise travel perk credited to your account each year.",
            "Access to all Platinum-exclusive flash sales, partner promotions, and invitation-only events.",
            "Complimentary travel planning consultation (unlimited sessions with a dedicated Contoso travel advisor).",
            "Annual Platinum anniversary gift: a curated travel accessory kit shipped to your address.",
            "Priority waitlist placement for sold-out flights, hotels, and experiences.",
        ],
    },
}

def generate_loyalty_pdf(tier_name: str, tier: dict) -> Path:
    pdf = ContosoPDF(tier["title"])
    pdf.add_page()

    # ── Introduction ────────────────────────────────────────────────
    pdf.section_title(f"Welcome to {tier['subtitle']}")
    pdf.body_text(
        f"Thank you for being a valued {tier['subtitle']} member of the Contoso Voyager Rewards program. "
        f"This document outlines the complete benefits available to you as a {tier['subtitle']} member. "
        "All benefits are effective immediately upon qualification and remain active for the duration of your tier status."
    )

    # ── Qualification ───────────────────────────────────────────────
    pdf.section_title("Qualification Criteria")
    pdf.body_text(tier["qualification"])

    # ── Points ──────────────────────────────────────────────────────
    pdf.section_title("Points Earning & Redemption")
    pdf.subsection_title("Earning Rate")
    pdf.body_text(f"As a {tier['subtitle']} member, you earn {tier['points_rate']} on all eligible bookings made through Contoso Travel Agency. Points are credited to your account within 48 hours of booking confirmation.")
    pdf.subsection_title("Redemption")
    pdf.body_text(tier["points_redemption"])

    # ── Flight benefits ─────────────────────────────────────────────
    pdf.section_title("Flight Benefits")
    for b in tier["flight_benefits"]:
        pdf.bullet(b)

    # ── Hotel benefits ──────────────────────────────────────────────
    pdf.section_title("Hotel & Accommodation Benefits")
    for b in tier["hotel_benefits"]:
        pdf.bullet(b)

    # ── Activity benefits ───────────────────────────────────────────
    pdf.section_title("Activities & Experiences Benefits")
    for b in tier["activity_benefits"]:
        pdf.bullet(b)

    # ── General benefits ────────────────────────────────────────────
    pdf.section_title("General Member Benefits")
    for b in tier["general_benefits"]:
        pdf.bullet(b)

    # ── Maintenance ─────────────────────────────────────────────────
    pdf.section_title("Tier Maintenance & Renewal")
    pdf.body_text(tier["maintenance"])

    # ── Contact ─────────────────────────────────────────────────────
    pdf.section_title("Contact & Support")
    pdf.body_text(
        "For questions about your Voyager Rewards membership or to access tier-specific support:\n"
        "  Email: rewards@contosotravel.ca\n"
        "  Phone: 1-800-CONTOSO (1-800-266-8676)\n"
        "  Online: www.contosotravel.ca/rewards\n\n"
        "Contoso Travel Agency reserves the right to modify the Voyager Rewards program, "
        "including tier benefits, qualification criteria, and points earning rates, with 60 days' notice to members."
    )

    out = LOYALTY_DIR / tier["filename"]
    pdf.save_to(out)
    return out


# ====================================================================
#  CANCELLATION POLICY DOCUMENTS
# ====================================================================

def generate_flight_cancellation_pdf() -> Path:
    pdf = ContosoPDF("Contoso Travel Agency - Flight Cancellation Policy")
    pdf.add_page()

    # ── Overview ────────────────────────────────────────────────────
    pdf.section_title("Overview")
    pdf.body_text(
        "This document describes the cancellation and modification policies for all flights booked through "
        "Contoso Travel Agency. Policies vary based on the timing of cancellation relative to the scheduled "
        "departure and your Contoso Voyager Rewards membership tier. All refund amounts are calculated based "
        "on the total fare paid, excluding taxes and surcharges, which are always refunded in full."
    )
    pdf.highlight_box(
        "Important: These policies apply to flights booked directly through Contoso Travel Agency. "
        "Flights booked through third-party platforms or directly with the airline are subject to that provider's cancellation terms."
    )

    # ── Standard cancellation timeline ──────────────────────────────
    pdf.section_title("Standard Cancellation Timeline")
    pdf.body_text(
        "The following refund schedule applies to all Contoso-booked flights. The cancellation window is "
        "measured from the moment the cancellation request is confirmed to the scheduled departure time of the first flight segment."
    )

    pdf.subsection_title("More than 30 days before departure")
    pdf.body_text(
        "Full refund (100%) of the base fare. The refund is processed to the original payment method. "
        "This is the most flexible cancellation window and applies to all members regardless of tier."
    )

    pdf.subsection_title("15 to 30 days before departure")
    pdf.body_text(
        "75% refund of the base fare. A 25% cancellation fee is retained by Contoso Travel Agency to cover "
        "administrative and airline processing costs."
    )
    pdf.tier_callout("Gold", "Gold members receive a 10% refund bonus, bringing the total refund to 85% of the base fare.")
    pdf.tier_callout("Platinum", "Platinum members receive a full 100% refund for cancellations in this window - no cancellation fee applies.")

    pdf.subsection_title("7 to 14 days before departure")
    pdf.body_text(
        "50% refund of the base fare. The remaining 50% is retained as a cancellation fee."
    )
    pdf.tier_callout("Gold", "Gold members receive a 10% refund bonus, bringing the total refund to 60% of the base fare.")
    pdf.tier_callout("Platinum", "Platinum members receive a full 100% refund for cancellations in this window.")

    pdf.subsection_title("Less than 7 days before departure")
    pdf.body_text(
        "25% refund of the base fare. This applies to cancellations made between 24 hours and 7 days before departure."
    )
    pdf.tier_callout("Gold", "Gold members receive a 10% refund bonus, bringing the total refund to 35% of the base fare.")
    pdf.tier_callout("Platinum", "Platinum members receive a 50% refund of the base fare in this window.")

    pdf.subsection_title("Less than 24 hours before departure")
    pdf.body_text(
        "No refund is available for standard members. The full base fare is forfeited. "
        "Taxes and government-imposed surcharges are still refunded."
    )
    pdf.tier_callout("Silver", "Silver members follow the standard policy - no refund within 24 hours of departure.")
    pdf.tier_callout("Gold", "Gold members may use their 1 complimentary rebooking (per calendar year) to reschedule instead of cancelling. If the rebooking benefit has already been used, standard policy applies.")
    pdf.tier_callout("Platinum", "Platinum members receive a 25% refund even within 24 hours of departure. Additionally, Platinum members have unlimited complimentary rebooking and can reschedule to any available flight at no cost.")

    # ── Change / modification fees ──────────────────────────────────
    pdf.section_title("Flight Modification & Change Fees")
    pdf.body_text(
        "Flight modifications include changes to travel dates, times, routing, or passenger names. "
        "Modifications are subject to availability and any fare difference between the original and new itinerary."
    )
    pdf.body_text(
        "A standard modification fee of $75 CAD per passenger, per change applies to all flight modifications."
    )
    pdf.tier_callout("Silver", "Silver members are exempt from the $75 change fee when modifications are made more than 72 hours before departure. Changes within 72 hours incur the standard fee.")
    pdf.tier_callout("Gold", "Gold members are exempt from change fees when modifications are made more than 48 hours before departure. Within 48 hours, the standard $75 fee applies. Gold members also receive 1 complimentary rebooking per calendar year, usable at any time - even within 24 hours of departure.")
    pdf.tier_callout("Platinum", "Platinum members never pay change fees, regardless of timing. All flight modifications are free of charge at any time before departure. Platinum members also enjoy unlimited complimentary rebooking to any available flight.")

    # ── Rebooking ───────────────────────────────────────────────────
    pdf.section_title("Rebooking Policy")
    pdf.body_text(
        "Instead of cancelling, you may choose to rebook your flight to a different date or route. "
        "Rebooking preserves the value of your original ticket and avoids cancellation fees."
    )
    pdf.body_text(
        "Standard rebooking fee: $50 CAD per passenger. Any fare difference between the original and new flight "
        "is charged or refunded accordingly."
    )
    pdf.tier_callout("Silver", "Silver members pay the standard $50 rebooking fee.")
    pdf.tier_callout("Gold", "Gold members receive 1 complimentary rebooking per calendar year (no $50 fee). Additional rebookings are charged at the standard rate.")
    pdf.tier_callout("Platinum", "Platinum members enjoy unlimited free rebooking. No rebooking fees ever apply, and fare differences are handled at the reduced Platinum rate.")

    # ── Refund processing ───────────────────────────────────────────
    pdf.section_title("Refund Processing")
    pdf.body_text(
        "Refunds are processed to the original payment method. Processing times vary by refund method:"
    )
    pdf.bullet("Credit card: 10-15 business days from the date the cancellation is confirmed.")
    pdf.bullet("Contoso Travel Credit: Instant. Travel credit is valid for 12 months and can be applied to any future booking.")
    pdf.bullet("Bank transfer: 15-20 business days.")
    pdf.tier_callout("Platinum", "Platinum members enjoy priority refund processing. Credit card refunds are processed within 3 business days, and bank transfers within 5 business days.")
    pdf.body_text(
        "You may opt to receive your refund as Contoso Travel Credit instead of a monetary refund. "
        "Travel credit refunds include a 5% bonus on the refund amount as a thank-you for your flexibility."
    )

    # ── Force majeure ───────────────────────────────────────────────
    pdf.section_title("Force Majeure & Exceptional Circumstances")
    pdf.body_text(
        "In the event of extraordinary circumstances beyond your control - including but not limited to natural disasters, "
        "severe weather events, government-imposed travel bans, airline strikes, pandemics, or security incidents - "
        "Contoso Travel Agency offers the following accommodations regardless of your membership tier:"
    )
    pdf.bullet("Full refund (100%) of the base fare, taxes, and surcharges.")
    pdf.bullet("Free rebooking to any available date within 12 months of the original departure.")
    pdf.bullet("Contoso Travel Credit with a 10% bonus if preferred over a monetary refund.")
    pdf.body_text(
        "Force majeure claims must be submitted within 30 days of the affected departure date. "
        "Contoso Travel Agency determines eligibility based on official government advisories and airline communications."
    )

    # ── How to request ──────────────────────────────────────────────
    pdf.section_title("How to Cancel or Modify Your Flight")
    pdf.body_text("You can submit a cancellation or modification request through any of the following channels:")
    pdf.bullet("Online: Log in to your Contoso Travel account at www.contosotravel.ca and navigate to 'My Bookings'. Select the flight and choose 'Cancel' or 'Modify'.")
    pdf.bullet("Phone: Call our support line at 1-800-CONTOSO (1-800-266-8676). Gold and Platinum members should use their dedicated tier support line for faster service.")
    pdf.bullet("Email: Send your request to cancellations@contosotravel.ca with your booking reference number, passenger names, and preferred resolution (refund or rebooking).")
    pdf.body_text(
        "All cancellation requests are confirmed via email within 1 hour of submission. "
        "The cancellation is effective from the timestamp of the confirmation email."
    )

    # ── Contact ─────────────────────────────────────────────────────
    pdf.section_title("Contact Information")
    pdf.body_text(
        "Contoso Travel Agency - Cancellations Department\n"
        "  Phone: 1-800-CONTOSO (1-800-266-8676)\n"
        "  Email: cancellations@contosotravel.ca\n"
        "  Online: www.contosotravel.ca/manage-booking\n"
        "  Hours: Monday - Sunday, 6 AM - 11 PM ET\n\n"
        "Policy effective date: January 1, 2026. Contoso Travel Agency reserves the right to update "
        "this policy with 30 days' notice to affected members."
    )

    out = CANCELLATION_DIR / "contoso-flight-cancellation-policy.pdf"
    pdf.save_to(out)
    return out


def generate_hotel_cancellation_pdf() -> Path:
    pdf = ContosoPDF("Contoso Travel Agency - Hotel Cancellation Policy")
    pdf.add_page()

    # ── Overview ────────────────────────────────────────────────────
    pdf.section_title("Overview")
    pdf.body_text(
        "This document describes the cancellation and modification policies for all hotel and accommodation "
        "bookings made through Contoso Travel Agency. Policies vary based on the timing of cancellation "
        "relative to the scheduled check-in date and your Contoso Voyager Rewards membership tier. "
        "All policies apply to standard bookings at Contoso partner hotels."
    )
    pdf.highlight_box(
        "Important: Special event periods, holiday blackout dates, and non-refundable rate bookings may have "
        "different cancellation terms. These exceptions are clearly marked at the time of booking."
    )

    # ── Standard cancellation ───────────────────────────────────────
    pdf.section_title("Standard Cancellation Policy")

    pdf.subsection_title("More than 48 hours before check-in")
    pdf.body_text(
        "Free cancellation with a full refund. No cancellation fee applies. The refund is processed to the "
        "original payment method within 10-15 business days."
    )
    pdf.body_text("This standard 48-hour free cancellation window applies to all members, including non-members.")

    pdf.subsection_title("24 to 48 hours before check-in")
    pdf.body_text(
        "A cancellation fee equal to one night's stay (including taxes) is charged. The remaining balance "
        "of the reservation is refunded."
    )
    pdf.tier_callout("Gold", "Gold members enjoy an extended free cancellation window. Cancellations made more than 24 hours before check-in are completely free - no one-night penalty applies.")
    pdf.tier_callout("Platinum", "Platinum members benefit from an even more generous window. Cancellations made more than 12 hours before check-in are completely free.")

    pdf.subsection_title("Less than 24 hours before check-in")
    pdf.body_text(
        "A cancellation fee equal to one night's stay is charged. For bookings of 3 nights or more, "
        "the fee is capped at 50% of the total reservation cost."
    )
    pdf.tier_callout("Gold", "Gold members who cancel within 24 hours are charged the standard one-night fee, but it is capped at 50% of the nightly rate (rather than the full nightly rate).")
    pdf.tier_callout("Platinum", "Platinum members who cancel within 12 hours of check-in are charged a maximum of one night's stay. Cancellations between 12 and 24 hours before check-in remain free for Platinum members.")

    pdf.subsection_title("No-show")
    pdf.body_text(
        "If you do not check in and do not cancel your reservation, you will be charged the full cost of "
        "the first night's stay. For multi-night bookings, the hotel may also cancel the remaining nights, "
        "and a no-show fee equal to one additional night may apply depending on the hotel's policy."
    )
    pdf.tier_callout("Gold", "Gold members' no-show fee is capped at 50% of the first night's rate.")
    pdf.tier_callout("Platinum", "Platinum members are granted 2 no-show fee waivers per calendar year. When a waiver is applied, no charge is incurred. After the 2 waivers are used, the standard one-night no-show fee applies.")

    # ── Modifications ───────────────────────────────────────────────
    pdf.section_title("Reservation Modifications")
    pdf.body_text(
        "You may modify your hotel reservation (dates, room type, number of guests) at any time, subject to "
        "availability. Modifications made more than 48 hours before check-in are free for all members."
    )
    pdf.body_text(
        "Modifications within 48 hours of check-in incur a $25 CAD processing fee per modification."
    )
    pdf.tier_callout("Gold", "Gold members are exempt from the $25 modification fee when changes are made more than 24 hours before check-in.")
    pdf.tier_callout("Platinum", "Platinum members never pay modification fees for hotel reservations, regardless of timing.")
    pdf.body_text(
        "Any rate difference between the original and modified reservation is charged or refunded accordingly."
    )

    # ── Special event periods ───────────────────────────────────────
    pdf.section_title("Special Event & Blackout Periods")
    pdf.body_text(
        "During designated special event periods (major conferences, festivals, holidays), partner hotels "
        "may enforce stricter cancellation policies. These typically include:"
    )
    pdf.bullet("Non-refundable deposits of 1-2 nights' stay required at booking.")
    pdf.bullet("Cancellation window extended to 7 days before check-in for free cancellation.")
    pdf.bullet("Late cancellations (within 7 days) forfeit the deposit.")
    pdf.body_text(
        "Special event periods are clearly marked at the time of booking. Contoso Travel Agency will always "
        "display the applicable cancellation terms before you confirm your reservation."
    )
    pdf.tier_callout("Gold", "Gold members receive a 50% reduction on non-refundable deposit requirements during special event periods.")
    pdf.tier_callout("Platinum", "Platinum members are exempt from non-refundable deposit requirements during special event periods. Standard Platinum cancellation terms apply even during blackout dates.")

    # ── Group bookings ──────────────────────────────────────────────
    pdf.section_title("Group Bookings")
    pdf.body_text(
        "Group bookings (5 or more rooms) follow a separate cancellation schedule:"
    )
    pdf.bullet("More than 60 days before check-in: Free cancellation for the entire group.")
    pdf.bullet("30 to 60 days before check-in: 50% of the first night's rate per room as a cancellation fee.")
    pdf.bullet("Less than 30 days before check-in: Full first night's rate per room as a cancellation fee.")
    pdf.body_text(
        "Individual rooms within a group booking may be cancelled separately without affecting the remaining rooms, "
        "provided the minimum group size (5 rooms) is maintained."
    )

    # ── Extended stays ──────────────────────────────────────────────
    pdf.section_title("Extended Stay Bookings")
    pdf.body_text(
        "Bookings of 14 nights or more are classified as extended stays and benefit from the following terms:"
    )
    pdf.bullet("Free cancellation up to 7 days before check-in (instead of the standard 48 hours).")
    pdf.bullet("Early departure (checking out before the original end date) incurs a fee equal to 2 nights' stay.")
    pdf.bullet("Partial cancellation (shortening the stay) is treated as a modification and follows modification rules.")
    pdf.tier_callout("Platinum", "Platinum members' early departure fee is waived for the first occurrence per calendar year.")

    # ── Refund processing ───────────────────────────────────────────
    pdf.section_title("Refund Processing")
    pdf.body_text(
        "Hotel refunds are processed to the original payment method. Processing times:"
    )
    pdf.bullet("Credit card: 10-15 business days.")
    pdf.bullet("Contoso Travel Credit: Instant. Travel credit includes a 5% bonus on the refund amount.")
    pdf.bullet("Bank transfer: 15-20 business days.")
    pdf.tier_callout("Platinum", "Platinum members receive priority refund processing: credit card refunds within 3 business days, bank transfers within 5 business days.")

    # ── How to request ──────────────────────────────────────────────
    pdf.section_title("How to Cancel or Modify Your Hotel Booking")
    pdf.body_text("Submit cancellation or modification requests through:")
    pdf.bullet("Online: www.contosotravel.ca > 'My Bookings' > select your hotel reservation > 'Cancel' or 'Modify'.")
    pdf.bullet("Phone: 1-800-CONTOSO (1-800-266-8676). Gold and Platinum members should use their dedicated support lines.")
    pdf.bullet("Email: cancellations@contosotravel.ca with your booking reference number and preferred resolution.")
    pdf.body_text(
        "Cancellation confirmations are sent via email within 1 hour. The cancellation is effective from the "
        "timestamp of the confirmation email."
    )

    # ── Contact ─────────────────────────────────────────────────────
    pdf.section_title("Contact Information")
    pdf.body_text(
        "Contoso Travel Agency - Hotel Reservations & Cancellations\n"
        "  Phone: 1-800-CONTOSO (1-800-266-8676)\n"
        "  Email: cancellations@contosotravel.ca\n"
        "  Online: www.contosotravel.ca/manage-booking\n"
        "  Hours: Monday - Sunday, 6 AM - 11 PM ET\n\n"
        "Policy effective date: January 1, 2026. Contoso Travel Agency reserves the right to update "
        "this policy with 30 days' notice."
    )

    out = CANCELLATION_DIR / "contoso-hotel-cancellation-policy.pdf"
    pdf.save_to(out)
    return out


def generate_activity_cancellation_pdf() -> Path:
    pdf = ContosoPDF("Contoso Travel Agency - Activity Cancellation Policy")
    pdf.add_page()

    # ── Overview ────────────────────────────────────────────────────
    pdf.section_title("Overview")
    pdf.body_text(
        "This document describes the cancellation and modification policies for all activities, tours, "
        "experiences, and restaurant reservations booked through Contoso Travel Agency. Policies vary "
        "based on the timing of cancellation and your Contoso Voyager Rewards membership tier."
    )
    pdf.highlight_box(
        "Important: Some premium experiences, private tours, and seasonal activities may have non-refundable "
        "components. These are clearly disclosed at the time of booking."
    )

    # ── Standard activities ─────────────────────────────────────────
    pdf.section_title("Standard Activity Cancellation Policy")

    pdf.subsection_title("More than 72 hours before the activity")
    pdf.body_text(
        "Full refund (100%) of the activity price. No cancellation fee applies. This is the standard "
        "free cancellation window for all activities booked through Contoso."
    )
    pdf.tier_callout("Gold", "Gold members enjoy an extended window - full refunds are available for cancellations made more than 48 hours before the activity (instead of the standard 72 hours).")
    pdf.tier_callout("Platinum", "Platinum members benefit from the most flexible terms - full refunds for cancellations made more than 24 hours before the activity.")

    pdf.subsection_title("24 to 72 hours before the activity")
    pdf.body_text(
        "50% refund of the activity price. A 50% cancellation fee is retained to cover provider costs "
        "and reservation holds."
    )
    pdf.tier_callout("Gold", "Gold members who cancel between 48 and 72 hours before the activity receive a full refund (this falls within the Gold extended window). Between 24 and 48 hours, Gold members receive the standard 50% refund.")
    pdf.tier_callout("Platinum", "Platinum members who cancel between 24 and 72 hours before the activity receive a full refund (within the Platinum extended window). Platinum members only face reduced refunds for cancellations within 24 hours.")

    pdf.subsection_title("Less than 24 hours before the activity")
    pdf.body_text(
        "No refund is available for standard members. The full activity price is forfeited."
    )
    pdf.tier_callout("Silver", "Silver members follow the standard no-refund policy within 24 hours.")
    pdf.tier_callout("Gold", "Gold members receive 1 complimentary last-minute cancellation per calendar year. When used, a full refund is provided even within 24 hours of the activity. After the annual allowance is used, the standard no-refund policy applies.")
    pdf.tier_callout("Platinum", "Platinum members enjoy unlimited last-minute cancellations. A full refund is provided for any cancellation, regardless of timing. Platinum members may also request priority rebooking for the same or a similar activity at a later date.")

    # ── Private and premium experiences ─────────────────────────────
    pdf.section_title("Private & Premium Experiences")
    pdf.body_text(
        "Private tours, VIP experiences, chef's table dinners, and other premium activities may include "
        "non-refundable components (e.g., venue deposits, private guide fees). These are disclosed at booking time. "
        "The refundable portion of the booking follows the standard cancellation timeline above."
    )
    pdf.body_text(
        "Non-refundable deposits typically range from 20% to 50% of the total experience price."
    )
    pdf.tier_callout("Platinum", "Platinum members are exempt from non-refundable deposit requirements for premium experiences. The full booking price follows the standard Platinum cancellation terms (full refund with 24+ hours notice, unlimited last-minute cancellations).")

    # ── Weather-dependent ───────────────────────────────────────────
    pdf.section_title("Weather-Dependent Activities")
    pdf.body_text(
        "Outdoor activities that are weather-dependent (e.g., sailing tours, hiking excursions, hot air balloon rides) "
        "follow special cancellation rules when cancellation is due to weather:"
    )
    pdf.bullet("If the activity provider cancels due to weather: Full refund or free rebooking to any available date within 6 months.")
    pdf.bullet("If you cancel due to weather concerns (provider has not cancelled): Standard cancellation timeline applies.")
    pdf.body_text(
        "Contoso Travel Agency partners with local weather services to provide advance notice when weather "
        "cancellations are likely. You will receive an email notification at least 4 hours before the activity "
        "when weather conditions may force cancellation."
    )

    # ── Restaurant reservations ─────────────────────────────────────
    pdf.section_title("Restaurant Reservations")
    pdf.body_text(
        "Restaurant reservations booked through Contoso Travel Agency follow simplified cancellation terms:"
    )
    pdf.bullet("More than 4 hours before the reservation: Free cancellation, no fee.")
    pdf.bullet("Less than 4 hours before the reservation: A no-show fee of $15-$50 CAD per person may apply, depending on the restaurant.")
    pdf.bullet("No-show (failure to arrive within 15 minutes of the reservation): The restaurant's standard no-show fee applies.")
    pdf.body_text(
        "Some high-demand restaurants require a non-refundable deposit at booking. This is clearly disclosed "
        "before you confirm the reservation."
    )
    pdf.tier_callout("Gold", "Gold members' restaurant no-show fees are capped at $25 CAD per person regardless of the restaurant's standard rate.")
    pdf.tier_callout("Platinum", "Platinum members receive 2 restaurant no-show fee waivers per calendar year. Platinum members also receive priority rebooking for fully booked restaurants.")

    # ── Group activity bookings ─────────────────────────────────────
    pdf.section_title("Group Activity Bookings")
    pdf.body_text(
        "Group bookings (8 or more participants) for activities follow adjusted cancellation terms:"
    )
    pdf.bullet("More than 7 days before the activity: Free cancellation for the entire group.")
    pdf.bullet("3 to 7 days before the activity: 25% cancellation fee.")
    pdf.bullet("Less than 3 days before the activity: 50% cancellation fee.")
    pdf.bullet("Individual participants may cancel separately without affecting the group, provided the minimum group size is maintained.")
    pdf.body_text(
        "Partial cancellations (reducing the group size below the minimum) may result in the per-person rate "
        "being adjusted to the standard (non-group) rate for the remaining participants."
    )

    # ── Modifications ───────────────────────────────────────────────
    pdf.section_title("Activity Modifications")
    pdf.body_text(
        "You may modify your activity booking (date, time, number of participants) subject to availability. "
        "Modifications made more than 72 hours before the activity are free for all members."
    )
    pdf.body_text("Modifications within 72 hours incur a $15 CAD processing fee per modification.")
    pdf.tier_callout("Gold", "Gold members are exempt from the processing fee for modifications made more than 48 hours before the activity.")
    pdf.tier_callout("Platinum", "Platinum members never pay modification fees for activities, regardless of timing. Platinum members can also request same-day activity swaps through their dedicated concierge.")

    # ── Refund processing ───────────────────────────────────────────
    pdf.section_title("Refund Processing")
    pdf.body_text("Activity refunds are processed to the original payment method. Processing times:")
    pdf.bullet("Credit card: 10-15 business days.")
    pdf.bullet("Contoso Travel Credit: Instant. Travel credit includes a 5% bonus on the refund amount.")
    pdf.bullet("Bank transfer: 15-20 business days.")
    pdf.tier_callout("Platinum", "Platinum members receive priority refund processing: credit card refunds within 3 business days, bank transfers within 5 business days.")

    # ── How to request ──────────────────────────────────────────────
    pdf.section_title("How to Cancel or Modify Your Activity Booking")
    pdf.body_text("Submit cancellation or modification requests through:")
    pdf.bullet("Online: www.contosotravel.ca > 'My Bookings' > select your activity > 'Cancel' or 'Modify'.")
    pdf.bullet("Phone: 1-800-CONTOSO (1-800-266-8676). Gold and Platinum members should use their dedicated support lines.")
    pdf.bullet("Email: cancellations@contosotravel.ca with your booking reference and preferred resolution.")
    pdf.body_text(
        "Cancellation confirmations are sent via email within 1 hour. The cancellation is effective from the "
        "timestamp of the confirmation email."
    )

    # ── Contact ─────────────────────────────────────────────────────
    pdf.section_title("Contact Information")
    pdf.body_text(
        "Contoso Travel Agency - Activities & Experiences\n"
        "  Phone: 1-800-CONTOSO (1-800-266-8676)\n"
        "  Email: cancellations@contosotravel.ca\n"
        "  Online: www.contosotravel.ca/manage-booking\n"
        "  Hours: Monday - Sunday, 6 AM - 11 PM ET\n\n"
        "Policy effective date: January 1, 2026. Contoso Travel Agency reserves the right to update "
        "this policy with 30 days' notice."
    )

    out = CANCELLATION_DIR / "contoso-activity-cancellation-policy.pdf"
    pdf.save_to(out)
    return out

# ====================================================================
# Knowledge base creation
# ====================================================================
def upload_document():
    pass

# ====================================================================
#  MAIN
# ====================================================================
def main():
    generated: list[Path] = []

    print("Generating Contoso Travel Agency documents...\n")

    # Loyalty program PDFs
    print("  Loyalty Program Tier Benefits:")
    for tier_name, tier_data in TIERS.items():
        path = generate_loyalty_pdf(tier_name, tier_data)
        generated.append(path)
        print(f"    {tier_name:10s} -> {path.relative_to(ROOT_DIR)}")

    # Cancellation policy PDFs
    print("\n  Cancellation Policies:")
    for label, gen_fn in [
        ("Flights", generate_flight_cancellation_pdf),
        ("Hotels", generate_hotel_cancellation_pdf),
        ("Activities", generate_activity_cancellation_pdf),
    ]:
        path = gen_fn()
        generated.append(path)
        print(f"    {label:10s} -> {path.relative_to(ROOT_DIR)}")

    print(f"\nDone. {len(generated)} PDF files generated.")


if __name__ == "__main__":
    main()
