from fastmcp import FastMCP
from fastmcp.server.providers import FileSystemProvider
from tools import flight_mcp
from pathlib import Path

mcp = FastMCP("Flight MCP Server",
              instructions="""Flight booking server that searches available flights between 
                              Canadian cities and European destinations, reserves seats 
                              by flight ID, and cancels reservations by reservation ID — 
                              all prices in CAD per person.""",
             providers=[
                 FileSystemProvider(Path(__file__).parent / "tools")
             ])


#mcp.include_router(reservation_mcp)

if __name__ == "__main__":
    mcp.run(transport='http',port=9000)