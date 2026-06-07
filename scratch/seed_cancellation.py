from backend.database import SessionLocal
from backend.models import CancellationReason

def seed():
    db = SessionLocal()
    reasons = [
        'Schedule Conflict',
        'Medical Reason / Sick',
        'Transportation Issue',
        'Forgot Appointment',
        'Feeling Better',
        'Other'
    ]
    for r in reasons:
        existing = db.query(CancellationReason).filter(CancellationReason.description == r).first()
        if not existing:
            db.add(CancellationReason(description=r))
    db.commit()
    db.close()
    print("Seeded Cancellation Reasons.")

if __name__ == '__main__':
    seed()
