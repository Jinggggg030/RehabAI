import os
from dotenv import load_dotenv
from sqlalchemy import create_engine, text

load_dotenv()
DATABASE_URL = os.environ.get("DATABASE_URL")
engine = create_engine(DATABASE_URL)

with engine.connect() as conn:
    try:
        conn.execute(text('ALTER TABLE "Physiotherapist" ADD COLUMN leave_start_date TIMESTAMP;'))
        conn.execute(text('ALTER TABLE "Physiotherapist" ADD COLUMN leave_end_date TIMESTAMP;'))
        conn.commit()
        print("Successfully added leave_start_date and leave_end_date to Physiotherapist.")
    except Exception as e:
        print(f"Error: {e}")
