from fastapi import APIRouter, Depends, HTTPException, Security
from dependencies import get_agent_factory, azure_scheme
from factory import AgentFactory
from typing import Annotated
from models import SessionInfo

router = APIRouter(prefix='/session')

# @router.get(path='new')
# def get_new_session(agent_factory: Annotated[AgentFactory, Depends(get_agent_factory)]) -> SessionInfo:
    

@router.get('hello', dependencies=[Security(azure_scheme)])
def hello_world() -> str:
    return 'hello world'