from fastapi import Request
from fastapi_azure_auth import SingleTenantAzureAuthorizationCodeBearer
from factory import AgentFactory
from services import ConversationService
from config import Config
from models import UserInfo

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

def get_user_info(request:Request) -> UserInfo:
    user = request.state.user
    return UserInfo(
        name=user.name,
        preferred_username=user.preferred_username
        # Add extra needed claims
    )

def get_access_token(request:Request) -> str:
    return request.state.user.access_token

def get_conversation_service(request:Request) -> ConversationService:
    return request.app.state.conversation_service

