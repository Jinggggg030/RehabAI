import os
import secrets

from dotenv import load_dotenv
from sqlalchemy import create_engine, text


load_dotenv(os.path.join(os.path.dirname(__file__), "..", ".env"))
database_url = os.environ.get("DATABASE_URL")
if not database_url:
    raise RuntimeError("DATABASE_URL not found")

engine = create_engine(database_url)
with engine.begin() as connection:
    connection.execute(
        text(
            'ALTER TABLE "Appointment" '
            "ADD COLUMN IF NOT EXISTS meeting_room VARCHAR(100) UNIQUE"
        )
    )
    missing_appointment_ids = connection.execute(
        text(
            'SELECT appointment_id FROM "Appointment" '
            "WHERE meeting_room IS NULL"
        )
    ).scalars().all()
    for appointment_id in missing_appointment_ids:
        connection.execute(
            text(
                'UPDATE "Appointment" SET meeting_room = :meeting_room '
                'WHERE appointment_id = :appointment_id'
            ),
            {
                "appointment_id": appointment_id,
                "meeting_room": f"rehab-ai-{secrets.token_hex(16)}",
            },
        )

print("Appointment meeting room column is ready.")
