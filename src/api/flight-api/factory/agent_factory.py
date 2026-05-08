import logging
from agent_framework import Agent
from azure.identity.aio import OnBehalfOfCredential
from agent_framework.foundry import FoundryAgent
from config import Config

logger = logging.getLogger(__name__)


class AgentFactory:

    def __init__(self, config:Config):
        self.config = config

    def create_agent(self,original_token:str) -> FoundryAgent:
        logger.info("Creating FoundryAgent '%s' (version: %s)", self.config.foundry_agent_name, self.config.foundry_agent_version)
        return FoundryAgent(
            project_endpoint=self.config.foundry_project_endpoint,
            agent_name=self.config.foundry_agent_name,
            allow_preview=True,
            agent_version=self.config.foundry_agent_version,
            credential=OnBehalfOfCredential(self.config.tenant_id,
                                            self.config.client_id,
                                            client_secret=self.config.client_secret,
                                            user_assertion=original_token)
        )   