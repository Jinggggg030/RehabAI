import os
import sys
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from backend.database import engine
from sqlalchemy import text

with engine.connect() as conn:
    res = conn.execute(text("SELECT pg_get_constraintdef(oid) FROM pg_constraint WHERE conname = 'check_rental_status';"))
    print(res.fetchone())
