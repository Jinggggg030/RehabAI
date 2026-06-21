import os

from dotenv import load_dotenv
from sqlalchemy import create_engine, text


load_dotenv(os.path.join(os.path.dirname(__file__), "..", ".env"))
database_url = os.environ.get("DATABASE_URL")
if not database_url:
    raise RuntimeError("DATABASE_URL not found")

engine = create_engine(database_url)
with engine.begin() as connection:
    connection.execute(text(
        'ALTER TABLE "Live_Chat_Session" '
        'ADD COLUMN IF NOT EXISTS teleconference_room VARCHAR(100)'
    ))
    connection.execute(text(
        'ALTER TABLE "Live_Chat_Session" '
        'ADD COLUMN IF NOT EXISTS teleconference_status VARCHAR(20)'
    ))
    connection.execute(text(
        'ALTER TABLE "Live_Chat_Session" '
        'ADD COLUMN IF NOT EXISTS consultation_prescription TEXT'
    ))
    connection.execute(text(
        'ALTER TABLE "Live_Chat_Session" '
        'ADD COLUMN IF NOT EXISTS consultation_appointment_id INTEGER '
        'REFERENCES "Appointment"(appointment_id)'
    ))

print("Live chat teleconference columns are ready.")
