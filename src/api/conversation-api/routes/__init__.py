from .session import router as session_router
from .conversation import router as conversation_router

routes = [
    session_router,
    conversation_router
]