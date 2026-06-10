import os
import sys
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from sqlalchemy import text
from backend.database import engine

reasons = [
    "Post-Surgery Recovery",
    "Acute Injury (e.g., sprain, strain, fracture)",
    "Chronic Pain Management (e.g., back or joint pain)",
    "Posture Correction & Ergonomics",
    "Home Physiotherapy Exercises",
    "Sports Event Preparation / Recovery",
    "Other (Please specify)"
]

with engine.begin() as conn:
    try:
        conn.execute(text('ALTER TABLE "Rental_Record" ADD COLUMN custom_reason VARCHAR(255);'))
        print("Added custom_reason column.")
    except Exception as e:
        print("Column custom_reason might already exist:", e)

    conn.execute(text('DELETE FROM "Rental_Reason"'))
    
    for reason in reasons:
        conn.execute(text('INSERT INTO "Rental_Reason" (description) VALUES (:desc)'), {"desc": reason})
        
    print("Inserted rental reasons successfully.")
