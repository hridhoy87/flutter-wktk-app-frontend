from datetime import datetime
from typing import Optional, List
from sqlmodel import SQLModel, Field, Relationship

class UserBase(SQLModel):
    phone: str = Field(index=True, unique=True)
    legal_name: str
    is_approved: bool = Field(default=False)
    is_admin: bool = Field(default=False)

class User(UserBase, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    password_hash: str
    created_at: datetime = Field(default_factory=datetime.utcnow)
    
    # Relationship
    created_channels: List["Channel"] = Relationship(back_populates="creator")

class UserCreate(UserBase):
    password: str

class UserRead(UserBase):
    id: int
    created_at: datetime

class ChannelBase(SQLModel):
    name: str

class Channel(ChannelBase, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    created_by: int = Field(foreign_key="user.id")
    created_at: datetime = Field(default_factory=datetime.utcnow)

    creator: User = Relationship(back_populates="created_channels")

class Token(SQLModel):
    access_token: str
    token_type: str

class TokenData(SQLModel):
    phone: Optional[str] = None
