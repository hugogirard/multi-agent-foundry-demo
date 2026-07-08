from fastmcp import FastMCP
from fastmcp.server.providers import FileSystemProvider
from fastmcp.server.auth.providers.azure import AzureProvider
from fastmcp.server.auth.providers.jwt import JWTVerifier
from fastmcp.server.auth.auth import MultiAuth
from fastmcp.server.dependencies import get_access_token
from starlette.applications import Starlette
from starlette.routing import Mount
from pathlib import Path
from config import Config

instructions="""Hotel search server that finds available hotels by city or country.
                Returns hotel details including name, location, star rating, 
                price per night, amenities, and room type."""

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
mcp = FastMCP("Hotel MCP Server",
              instructions=instructions,
              providers=providers,
              auth=auth_provider)

app = mcp.http_app()

if __name__ == "__main__":    
    mcp.run(transport='http',port=9001)