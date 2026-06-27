import os
from sqlmodel import SQLModel, create_engine, Session
from dotenv import load_dotenv

load_dotenv()

# Neon DB Connection String from Environment
DATABASE_URL = os.getenv("DATABASE_URL") or 'postgresql://neondb_owner:npg_pWiU4JO3NsFS@ep-nameless-forest-aosdmrbj-pooler.c-2.ap-southeast-1.aws.neon.tech/neondb?sslmode=require&channel_binding=require'

engine = create_engine(DATABASE_URL, echo=True)

def init_db():
    SQLModel.metadata.create_all(engine)

def get_session():
    with Session(engine) as session:
        yield session
