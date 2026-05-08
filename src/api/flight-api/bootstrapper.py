from fastapi import FastAPI
from dependencies import azure_scheme
from fastapi.middleware.cors import CORSMiddleware
from config import Config
from contextlib import asynccontextmanager
from dotenv import load_dotenv
from factory import AgentFactory
from fastapi_azure_auth import SingleTenantAzureAuthorizationCodeBearer
from pydantic import AnyHttpUrl, computed_field


config = Config()

@asynccontextmanager
async def lifespan_event(app: FastAPI):
    
    app.state.agent_factory = AgentFactory(config=config)

    # Load config from the OpenId config endpoint
    await azure_scheme.openid_config.load_config()

    yield


class Boostrapper:

    def run(self) -> FastAPI:

        app = FastAPI(lifespan=lifespan_event,
                      swagger_ui_oauth2_redirect_url='/oauth2-redirect',
                      swagger_ui_init_oauth={
                            'usePkceWithAuthorizationCodeGrant': True,
                            'clientId': config.open_api_client_id,
                            'scopes': config.scope_name
                      })
        
        app.add_middleware(
            CORSMiddleware,
            allow_origins=['*'],
            allow_credentials=True,
            allow_methods=['*'],
            allow_headers=['*'],
        )

        self._configure_monitoring()

        return app
    
    def _configure_monitoring(self):
        pass