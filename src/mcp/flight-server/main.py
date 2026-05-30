from fastmcp import FastMCP
from fastmcp.server.providers import FileSystemProvider
from fastmcp.server.auth.providers.azure import AzureProvider
from fastmcp.server.auth.providers.jwt import JWTVerifier
from fastmcp.server.auth.auth import MultiAuth
from fastmcp.server.dependencies import get_access_token
from starlette.applications import Starlette
from starlette.routing import Mount
from tools import flight_mcp
from pathlib import Path
from config import Config
import uvicorn

instructions="""Flight booking server that searches available flights between 
                Canadian cities and European destinations, reserves seats 
                by flight ID, and cancels reservations by reservation ID — 
                all prices in CAD per person."""

providers=[
    FileSystemProvider(Path(__file__).parent / "tools") # Browse directory to retrieve all configured tools
]

# OAuth Proxy for interactive clients (e.g., VS Code)
azure_proxy = AzureProvider(
    client_id=Config.entra_client_id(),
    client_secret=Config.client_secret(),
    tenant_id=Config.tenant_id(),
    base_url=Config.oauth_redirect_url(),
    identifier_uri=Config.identifier_uri(),
    required_scopes=[Config.scope()]
)

# Direct JWT verifier for raw Azure AD tokens (e.g., Foundry Agent Service OAuth Identity Passthrough)
azure_jwt_verifier = JWTVerifier(
    jwks_uri=f"https://login.microsoftonline.com/{Config.tenant_id()}/discovery/v2.0/keys",
    issuer=f"https://login.microsoftonline.com/{Config.tenant_id()}/v2.0",
    audience=[Config.entra_client_id(), Config.identifier_uri()],
    algorithm="RS256",
    required_scopes=[Config.scope()]
)

# MultiAuth: tries proxy first (VS Code), falls back to direct JWT validation (Foundry)
auth_provider = MultiAuth(
    server=azure_proxy,
    verifiers=[azure_jwt_verifier]
)

# --- MCP (JWT only, no OAuth discovery) ---
mcp = FastMCP("Flight MCP Server",
              instructions=instructions,
              providers=providers,
              auth=auth_provider)

# --- MCP for VS Code, Claude, other client (full OAuth + JWT) ---
# mcp_oauth_discovery = FastMCP("Flight MCP Server",
#                                instructions=instructions,
#                                providers=providers,
#                                auth=auth_provider)

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

# app = Starlette(routes=[
#     Mount('/mcp', app=mcp.http_app(transport='http')),
#     Mount('/mcp-oauth', app=mcp_oauth_discovery.http_app(transport='http'))
# ])

if __name__ == "__main__":
    #uvicorn.run(app, host="0.0.0.0", port=9000)
    mcp.run(transport='http',port=9000)