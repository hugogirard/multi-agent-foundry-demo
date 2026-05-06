from fastmcp import FastMCP
from fastmcp.server.providers import FileSystemProvider
from fastmcp.server.auth.providers.azure import AzureProvider
from fastmcp.server.dependencies import get_access_token
from tools import flight_mcp
from pathlib import Path
from config import Config


auth_provider = AzureProvider(
    client_id=Config.entra_client_id(),
    client_secret=Config.client_secret(),
    tenant_id=Config.tenant_id(),
    base_url=Config.oauth_redirect_url(),
    identifier_uri="api://app-mcp-fligh-server-penkryleu3m3e",
    required_scopes=["flight_reservation_information"]
)

mcp = FastMCP("Flight MCP Server",
              instructions="""Flight booking server that searches available flights between 
                              Canadian cities and European destinations, reserves seats 
                              by flight ID, and cancels reservations by reservation ID — 
                              all prices in CAD per person.""",
             providers=[
                 FileSystemProvider(Path(__file__).parent / "tools") # Browse directory to retrieve all configured tools
             ],
             auth=auth_provider)


# Endpoint to test the authenticated user info only
@mcp.tool()
async def get_user_info() -> dict:
    """Returns information about the authenticated Azure user."""
    
    token = get_access_token()
    # The AzureProvider stores user data in token claims
    return {
        "audience": token.claims.get("aud"),
        "preferredUsername": token.claims.get("preferred_username"),
        "name": token.claims.get("name")
    }

#mcp.include_router(reservation_mcp)

app = mcp.http_app()

if __name__ == "__main__":
    mcp.run(transport='http',port=9000)