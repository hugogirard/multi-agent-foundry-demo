import logging
from fastapi import APIRouter, Depends, HTTPException, Security
from dependencies import get_conversation_service, get_access_token, azure_scheme
from starlette.responses import StreamingResponse
from models.conversation import Conversation
from services import ConversationService
from typing import Annotated

logger = logging.getLogger(__name__)

router = APIRouter(prefix='/conversation',dependencies=[Security(azure_scheme)])

@router.post('/')
async def run(conversation:Conversation, 
              access_token: Annotated[str,Depends(get_access_token)],
              conversation_service: Annotated[ConversationService, Depends(get_conversation_service)]):
    try:
        logger.info("Conversation request for session %s", conversation.session_info.session_id)
        return StreamingResponse(conversation_service.run(access_token,conversation),media_type="text/event-stream")
    except Exception as err:
        logger.exception("Failed to start conversation stream")
        raise HTTPException(status_code=500, detail='Internal Server Error')