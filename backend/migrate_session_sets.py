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
            'ALTER TABLE "Session_Log" '
            "ADD COLUMN IF NOT EXISTS completed_sets INTEGER"
        )
    )
    connection.execute(
        text(
            'ALTER TABLE "Session_Log" '
            "ADD COLUMN IF NOT EXISTS planned_sets INTEGER"
        )
    )

print("Session_Log set columns are ready.")
