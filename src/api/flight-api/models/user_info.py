from pydantic import BaseModel


class UserInfo(BaseModel):
    name: str
    preferred_username: str    