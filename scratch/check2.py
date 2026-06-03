from backend.database import engine
from sqlalchemy import text
with engine.connect() as conn:
    print(conn.execute(text('SELECT user_id, email, role FROM "User"')).fetchall())
