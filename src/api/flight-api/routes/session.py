import logging
from fastapi import APIRouter, Depends, HTTPException, Security
from dependencies import get_agent_factory, get_access_token, get_user_info, azure_scheme
from factory import AgentFactory
from typing import Annotated
from models import SessionInfo

logger = logging.getLogger(__name__)

router = APIRouter(prefix='/session')

@router.get(path='/new',dependencies=[Security(azure_scheme)])
def get_new_session(agent_factory: Annotated[AgentFactory, Depends(get_agent_factory)],
                    access_token: Annotated[str,Depends(get_access_token)]) -> SessionInfo:
    
    try:
        agent = agent_factory.create_agent(original_token=access_token)

        session = agent.create_session()
        logger.info("New session created: %s", session.session_id)
        return SessionInfo(
            sessionId=session.session_id,
            serviceSessionId=session.service_session_id
        )
    except Exception as err:
        logger.exception("Failed to create new session")
        raise HTTPException(status_code=500,detail='Internal Server Error')

