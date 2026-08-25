from sqlalchemy import text

from database import engine


with engine.begin() as connection:
    connection.execute(text(
        'ALTER TABLE "Session_Log" '
        'ADD COLUMN IF NOT EXISTS purpose VARCHAR(120)'
    ))

print("Session_Log.purpose is ready.")
