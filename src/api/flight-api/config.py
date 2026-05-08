from dotenv import load_dotenv
import os

class Config:

    def __init__(self):
        load_dotenv(override=True)

    @property
    def foundry_agent_name(self) -> str:
        return os.getenv('AGENT_NAME')
    
    @property
    def foundry_agent_version(self) -> str:
        return os.getenv('AGENT_VERSION')
    
    @property
    def identity_client_id(self) -> str:
        return os.getenv('AZURE_CLIENT_ID')
    
    @property
    def tenant_id(self) -> str:
        return os.getenv('TENANT_ID')
    
    @property
    def client_id(self) -> str:
        return os.getenv('CLIENT_ID')
    
    @property
    def client_secret(self) -> str:
        return os.getenv('CLIENT_SECRET')    
    
    @property
    def open_api_client_id(self) -> str:
        return os.getenv('OPENAPI')

    @property
    def scope_name(self) -> str:
        return os.getenv('SCOPE_URI')

    @property
    def scope_description(self) -> str:
        return 'user_impersonation'