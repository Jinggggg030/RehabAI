import os
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker
from dotenv import load_dotenv

from models import Base

load_dotenv(os.path.join(os.path.dirname(__file__), '..', '.env'))
database_url = os.environ.get("DATABASE_URL")
if not database_url:
    print("DATABASE_URL not found!")
    exit(1)

engine = create_engine(database_url)

# Drop specific tables
print("Dropping old tables...")
with engine.connect() as conn:
    try:
        conn.execute(text("DROP TABLE IF EXISTS \"Self_Scheduled_Exercise\" CASCADE;"))
        conn.execute(text("DROP TABLE IF EXISTS \"Session_Log\" CASCADE;"))
        conn.commit()
        print("Dropped tables successfully.")
    except Exception as e:
        print(f"Error dropping tables: {e}")

print("Creating new tables...")
Base.metadata.create_all(bind=engine)
print("Created tables.")

print("Altering User table to add fcm_token...")
with engine.connect() as conn:
    try:
        conn.execute(text("ALTER TABLE \"User\" ADD COLUMN fcm_token VARCHAR(255);"))
        conn.commit()
        print("Added fcm_token to User table.")
    except Exception as e:
        print(f"Column might already exist: {e}")

print("Migration complete!")
