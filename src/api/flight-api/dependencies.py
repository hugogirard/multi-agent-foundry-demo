from fastapi import Request
from fastapi_azure_auth import SingleTenantAzureAuthorizationCodeBearer
from factory import AgentFactory
from config import Config

config = Config()

# Configure EntraID
azure_scheme = SingleTenantAzureAuthorizationCodeBearer(
    app_client_id=config.client_id,
    tenant_id=config.tenant_id,
    scopes={
        config.scope_name: config.scope_description
    }
)

def get_agent_factory(request:Request) -> AgentFactory:
    return request.app.state.agent_factory