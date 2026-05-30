import json
import logging
from factory.agent_factory import AgentFactory
from models import Conversation, SessionInfo

logger = logging.getLogger(__name__)

class ConversationService:

    def __init__(self,agent_factory:AgentFactory):
        self.agent_factory = agent_factory


    async def run(self,original_token:str, conversation:Conversation):
        try:
            agent = self.agent_factory.create_agent(original_token=original_token)

            service_session_id = conversation.session_info.service_session_id
            if service_session_id:
                session = agent.get_session(service_session_id=service_session_id,
                                            session_id=conversation.session_info.session_id)
            else:
                session = agent.create_session(session_id=conversation.session_info.session_id)
            logger.info("Running conversation for session %s", session.session_id)
            
            session_info:SessionInfo = None
            consent_sent = False
            async for update in agent.run(conversation.prompt, session=session, stream=True):            
                if not consent_sent:
                    for content in update.contents:
                        if content.type == "oauth_consent_request":
                            session_info = SessionInfo(
                                sessionId=session.session_id,
                                serviceSessionId=session.service_session_id,
                                consentLink=content.consent_link
                            )
                            consent_sent = True
                            break
                
                if consent_sent:
                    break

                if update.text:
                    yield json.dumps({"type": "content", "text": update.text})

            if not session_info:
                session_info = SessionInfo(
                    sessionId=session.session_id,
                    serviceSessionId=session.service_session_id
                )

            yield json.dumps({"type": "session_info", **json.loads(session_info.model_dump_json(by_alias=True, exclude_none=True))})                
        except Exception as e:
            logger.exception("Error during conversation for session %s", conversation.session_info.session_id)
            yield json.dumps({"type": "error", "text": str(e)})