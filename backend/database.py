import os
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from dotenv import load_dotenv

# Load variables from the .env file
load_dotenv()

# Get the PostgreSQL Connection String from the environment variables
DATABASE_URL = os.environ.get("DATABASE_URL")

if not DATABASE_URL:
    raise ValueError("No DATABASE_URL found in .env file. Please add your Supabase connection string!")

# Create the SQLAlchemy engine
# Supabase uses PostgreSQL, so we connect directly to it
engine = create_engine(DATABASE_URL)

# Create a session factory to be used in our API routes
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

def get_db():
    """
    Dependency function to get a database session for each API request.
    It automatically closes the session when the request is done.
    """
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
