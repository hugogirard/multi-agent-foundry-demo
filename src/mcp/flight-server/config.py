from dotenv import load_dotenv
import os

load_dotenv(override=True)

class Config:

    @staticmethod
    def cosmos_db_cnx_string() -> str:
        return os.getenv('COSMOS_DB_CONNECTION_STRING')
    
    @staticmethod
    def cosmos_db() -> str:
        return os.getenv('COSMOS_DATABASE')
    
    @staticmethod
    def flight_container() -> str:
        return os.getenv('FLIGHT_CONTAINER')
    
    @staticmethod
    def oauth_redirect_url() -> str:
        return os.getenv('REDIRECT_URL')
    
    @staticmethod
    def entra_client_id() -> str:
        return os.getenv('ENTRA_CLIENT_ID')

    @staticmethod
    def client_secret() -> str:
        return os.getenv('ENTRA_CLIENT_SECRET')

    @staticmethod
    def tenant_id() -> str:
        return os.getenv('TENANT_ID')

    @staticmethod
    def identifier_uri() -> str:
        return os.getenv('IDENTIFIER_URI')
    
    @staticmethod
    def scope() -> str:
        return os.getenv('SCOPE')