import sys
sys.path.append('backend')
from sqlalchemy import create_engine, text
from database import SQLALCHEMY_DATABASE_URL
engine = create_engine(SQLALCHEMY_DATABASE_URL)
with engine.connect() as conn:
    conn.execute(text("UPDATE appointments SET status='Cancelled' WHERE appointment_id=1"))
    conn.commit()
print("Done!")
