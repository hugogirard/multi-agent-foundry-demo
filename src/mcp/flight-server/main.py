from fastmcp import FastMCP
from tools import flight_mcp, reservation_mcp

mcp = FastMCP("Flight MCP Server",
              instructions="""Flight booking server that searches available flights between 
                              Canadian cities and European destinations, reserves seats 
                              by flight ID, and cancels reservations by reservation ID — 
                              all prices in CAD per person.""")

mcp.include_router(flight_mcp)
mcp.include_router(reservation_mcp)

if __name__ == "__main__":
    mcp.run(transport='http')