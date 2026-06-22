from sqlalchemy import text

from backend.database import engine


def migrate() -> None:
    with engine.begin() as connection:
        connection.execute(text(
            'ALTER TABLE "Session_Log" '
            'ADD COLUMN IF NOT EXISTS session_origin VARCHAR(20)'
        ))
    print("Session_Log.session_origin is ready.")


if __name__ == "__main__":
    migrate()
