from fastapi import FastAPI, Depends, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from sqlmodel import Session, select
from typing import List
import hashlib
import time

from .database import get_session, init_db
from .models import User, UserCreate, UserRead, Token, TokenData, Channel
from .auth import verify_password, get_password_hash, create_access_token, SECRET_KEY, ALGORITHM
from jose import JWTError, jwt

app = FastAPI(title="WalkieTalkie Backend")

# CORS Configuration for Flutter Web & Mobile
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], # In production, replace with your specific domains
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token")

@app.on_event("startup")
def on_startup():
    init_db()

async def get_current_user(token: str = Depends(oauth2_scheme), session: Session = Depends(get_session)):
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        phone: str = payload.get("sub")
        if phone is None:
            raise credentials_exception
        token_data = TokenData(phone=phone)
    except JWTError:
        raise credentials_exception
    user = session.exec(select(User).where(User.phone == token_data.phone)).first()
    if user is None:
        raise credentials_exception
    return user

async def get_current_admin(current_user: User = Depends(get_current_user)):
    if not current_user.is_admin:
        raise HTTPException(status_code=403, detail="Not an admin")
    return current_user

@app.post("/register", response_model=UserRead)
def register(user_in: UserCreate, session: Session = Depends(get_session)):
    db_user = session.exec(select(User).where(User.phone == user_in.phone)).first()
    if db_user:
        raise HTTPException(status_code=400, detail="Phone already registered")
    
    hashed_pw = get_password_hash(user_in.password)
    new_user = User(
        phone=user_in.phone,
        legal_name=user_in.legal_name,
        password_hash=hashed_pw,
        is_approved=False, # Manual approval required
        is_admin=False
    )
    session.add(new_user)
    session.commit()
    session.refresh(new_user)
    return new_user

@app.post("/token", response_model=Token)
def login(form_data: OAuth2PasswordRequestForm = Depends(), session: Session = Depends(get_session)):
    user = session.exec(select(User).where(User.phone == form_data.username)).first()
    if not user or not verify_password(form_data.password, user.password_hash):
        raise HTTPException(status_code=400, detail="Incorrect phone or password")
    if not user.is_approved:
        raise HTTPException(status_code=403, detail="User not approved by admin")
    
    access_token = create_access_token(data={"sub": user.phone})
    return {"access_token": access_token, "token_type": "bearer"}

# Admin Endpoints
@app.get("/admin/pending-users", response_model=List[UserRead])
def get_pending_users(admin: User = Depends(get_current_admin), session: Session = Depends(get_session)):
    users = session.exec(select(User).where(User.is_approved == False)).all()
    return users

@app.patch("/admin/approve-user/{user_id}")
def approve_user(user_id: int, admin: User = Depends(get_current_admin), session: Session = Depends(get_session)):
    user = session.get(User, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    user.is_approved = True
    session.add(user)
    session.commit()
    return {"status": "success"}

@app.delete("/admin/reject-user/{user_id}")
def reject_user(user_id: int, admin: User = Depends(get_current_admin), session: Session = Depends(get_session)):
    user = session.get(User, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    session.delete(user)
    session.commit()
    return {"status": "deleted"}

# TURN Credentials Helper (Simulated Coturn REST API authentication)
@app.get("/turn-credentials")
def get_turn_credentials(current_user: User = Depends(get_current_user)):
    # COTURN secret mechanism: user:timestamp and hmac-sha1(secret, user:timestamp)
    secret = "my-coturn-shared-secret"
    ttl = 3600 * 24 # 24 hours
    timestamp = int(time.time()) + ttl
    username = f"{timestamp}:{current_user.phone}"
    
    # Simple HMAC simulation for demo
    password = hashlib.sha1(f"{username}:{secret}".encode()).hexdigest()
    
    return {
        "username": username,
        "password": password,
        "ttl": ttl,
        "uris": ["turn:my-turn-server.com:3478", "stun:my-turn-server.com:3478"]
    }
