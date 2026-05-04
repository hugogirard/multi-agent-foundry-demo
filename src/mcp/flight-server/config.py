from dotenv import load_dotenv
import os

load_dotenv(override=True)

class Config:

    @staticmethod
    def cosmos_db_cnx_string():
        return os.getenv('COSMOS_DB_CONNECTION_STRING')
    
    @staticmethod
    def cosmos_db():
        return os.getenv('COSMOS_DATABASE')
    
    @staticmethod
    def flight_container():
        return os.getenv('FLIGHT_CONTAINER')