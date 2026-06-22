import os

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
            'ALTER TABLE "Prescribed_Exercise" '
            "ADD COLUMN IF NOT EXISTS assigned_reps INTEGER"
        )
    )
    connection.execute(
        text(
            'ALTER TABLE "Prescribed_Exercise" '
            "ADD COLUMN IF NOT EXISTS assigned_days INTEGER NOT NULL DEFAULT 1"
        )
    )
    connection.execute(
        text(
            'ALTER TABLE "Prescribed_Exercise" '
            "ADD COLUMN IF NOT EXISTS assigned_tracking_mode VARCHAR(20) "
            "NOT NULL DEFAULT 'duration'"
        )
    )
    connection.execute(
        text(
            'ALTER TABLE "Prescribed_Exercise" '
            "ADD COLUMN IF NOT EXISTS assigned_at TIMESTAMP NOT NULL "
            "DEFAULT CURRENT_TIMESTAMP"
        )
    )

print("Prescription exercise settings columns are ready.")
