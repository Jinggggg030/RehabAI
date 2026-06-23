from typing import Optional, List
from fastapi import FastAPI, Depends, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session
from sqlalchemy import text
from pydantic import BaseModel
from backend.database import engine, get_db
from backend import models
from fastapi.responses import StreamingResponse
from sqlalchemy.orm.attributes import flag_modified
import cv2
from backend.ai.pose_detector import PoseDetector
from backend.ai.angle_calculator import calculate_angle
from backend.ai.chatbot import chatbot_instance
from datetime import datetime, timedelta
import secrets

models.Base.metadata.create_all(bind=engine)

# create_all() does not add columns to existing tables. Keep this additive
# migration here so existing installations can start safely after upgrading.
with engine.begin() as connection:
    connection.execute(text(
        'ALTER TABLE "Session_Log" '
        'ADD COLUMN IF NOT EXISTS session_origin VARCHAR(20)'
    ))
    connection.execute(text(
        'ALTER TABLE "Prescribed_Exercise" '
        'ADD COLUMN IF NOT EXISTS assigned_reps INTEGER'
    ))
    connection.execute(text(
        'ALTER TABLE "Appointment" '
        'ADD COLUMN IF NOT EXISTS meeting_room VARCHAR(100) UNIQUE'
    ))
    missing_appointment_ids = connection.execute(text(
        'SELECT appointment_id FROM "Appointment" WHERE meeting_room IS NULL'
    )).scalars().all()
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
    connection.execute(text(
        'ALTER TABLE "Prescribed_Exercise" '
        'ADD COLUMN IF NOT EXISTS assigned_days INTEGER NOT NULL DEFAULT 1'
    ))
    connection.execute(text(
        'ALTER TABLE "Prescribed_Exercise" '
        'ADD COLUMN IF NOT EXISTS assigned_at TIMESTAMP NOT NULL '
        'DEFAULT CURRENT_TIMESTAMP'
    ))
    connection.execute(text(
        'ALTER TABLE "Prescribed_Exercise" '
        "ADD COLUMN IF NOT EXISTS assigned_tracking_mode VARCHAR(20) "
        "NOT NULL DEFAULT 'duration'"
    ))
    connection.execute(text(
        'ALTER TABLE "Live_Chat_Session" '
        'ADD COLUMN IF NOT EXISTS teleconference_room VARCHAR(100)'
    ))
    connection.execute(text(
        'ALTER TABLE "Student" '
        'ADD COLUMN IF NOT EXISTS profile_picture VARCHAR(255)'
    ))
    connection.execute(text(
        'ALTER TABLE "Live_Chat_Session" '
        'ADD COLUMN IF NOT EXISTS teleconference_status VARCHAR(20)'
    ))
    connection.execute(text(
        'ALTER TABLE "Live_Chat_Session" '
        'ADD COLUMN IF NOT EXISTS consultation_prescription TEXT'
    ))
    connection.execute(text(
        'ALTER TABLE "Live_Chat_Session" '
        'ADD COLUMN IF NOT EXISTS consultation_appointment_id INTEGER '
        'REFERENCES "Appointment"(appointment_id)'
    ))

app = FastAPI(title="Rehab AI Backend")

def ensure_meeting_room(appointment: models.Appointment) -> str:
    """Return a non-guessable room shared only through appointment responses."""
    if not appointment.meeting_room:
        appointment.meeting_room = f"rehab-ai-{secrets.token_hex(16)}"
    return appointment.meeting_room

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allows all origins
    allow_credentials=False, # Must be False if origins is '*'
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/")
def read_root():
    return {"message": "Welcome to the Rehab AI API! Connected to Supabase Successfully."}

class UserProfileCreate(BaseModel):
    supabase_id: str
    username: str
    identity_number: str
    email: str
    gender: str
    contact_number: str
    address: str
    accommodation_type: str | None = None
    matric_no: str | None = None

@app.post("/users/profile")
def create_user_profile(profile: UserProfileCreate, db: Session = Depends(get_db)):
    existing_user = db.query(models.User).filter(models.User.supabase_id == profile.supabase_id).first()
    if existing_user:
        raise HTTPException(status_code=400, detail="User profile already exists")
    
    # Check if this email was pre-registered by the admin
    pre_registered = db.query(models.User).filter(
        models.User.email == profile.email,
        models.User.supabase_id.is_(None)
    ).first()
    
    if pre_registered:
        pre_registered.supabase_id = profile.supabase_id
        if profile.username:
            pre_registered.username = profile.username
        if profile.identity_number:
            pre_registered.identity_number = profile.identity_number
        if profile.gender:
            pre_registered.gender = profile.gender
        if profile.contact_number:
            pre_registered.contact_number = profile.contact_number
        if profile.address:
            pre_registered.address = profile.address
        if profile.accommodation_type:
            pre_registered.accommodation_type = profile.accommodation_type
            
        db.commit()
        db.refresh(pre_registered)
        return {"message": "Profile linked successfully", "user_id": pre_registered.user_id, "role": pre_registered.role}
        
    new_user = models.User(
        supabase_id=profile.supabase_id,
        username=profile.username,
        identity_number=profile.identity_number,
        email=profile.email,
        gender=profile.gender,
        contact_number=profile.contact_number,
        address=profile.address,
        accommodation_type=profile.accommodation_type,
        role='S'
    )
    db.add(new_user)
    db.commit()
    db.refresh(new_user)

    new_student = models.Student(
        student_id=new_user.user_id,
        matric_no=profile.matric_no
    )
    db.add(new_student)
    db.commit()
    
    return {"message": "Profile created successfully", "user_id": new_user.user_id, "role": new_user.role}


class UserProfileUpdate(BaseModel):
    username: str = None
    email: str = None
    identity_number: str = None
    gender: str = None
    contact_number: str = None
    address: str = None
    accommodation_type: str = None
    matric_no: str = None
    profile_picture: str = None

@app.put("/users/profile/{supabase_id}")
def update_user_profile(supabase_id: str, profile: UserProfileUpdate, db: Session = Depends(get_db)):
    user = db.query(models.User).filter(models.User.supabase_id == supabase_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
        
    if profile.username is not None:
        user.username = profile.username
    if profile.email is not None:
        user.email = profile.email
    if profile.identity_number is not None:
        user.identity_number = profile.identity_number
    if profile.gender is not None:
        user.gender = profile.gender
    if profile.contact_number is not None:
        user.contact_number = profile.contact_number
    if profile.address is not None:
        user.address = profile.address
    if profile.accommodation_type is not None:
        user.accommodation_type = profile.accommodation_type
        
    if user.role == 'S' and (
        profile.matric_no is not None or profile.profile_picture is not None
    ):
        student = db.query(models.Student).filter(models.Student.student_id == user.user_id).first()
        if student:
            if profile.matric_no is not None:
                student.matric_no = profile.matric_no
            if profile.profile_picture is not None:
                student.profile_picture = profile.profile_picture
    db.commit()

    return {"message": "Profile updated successfully"}

@app.get("/users/profile/{supabase_id}")
def check_user_profile(supabase_id: str, db: Session = Depends(get_db)):
    if supabase_id.isdigit():
        user = db.query(models.User).filter(models.User.user_id == int(supabase_id)).first()
    else:
        user = db.query(models.User).filter(models.User.supabase_id == supabase_id).first()
    
    if user:
        if user.role == 'P':
            therapist = db.query(models.Physiotherapist).filter(models.Physiotherapist.therapist_id == user.user_id).first()
            return {
                "exists": True, 
                "user_id": user.user_id, 
                "role": user.role,
                "username": user.username,
                "email": user.email,
                "identity_number": user.identity_number,
                "gender": user.gender,
                "contact_number": user.contact_number,
                "address": user.address,
                "accommodation_type": user.accommodation_type,
                "profile_picture": None,
                "matric_no": None,
                "specialization": therapist.specialization if therapist else ""
            }
        else:
            student = db.query(models.Student).filter(models.Student.student_id == user.user_id).first()
            return {
                "exists": True, 
                "user_id": user.user_id, 
                "role": user.role,
                "username": user.username,
                "email": user.email,
                "identity_number": user.identity_number,
                "gender": user.gender,
                "contact_number": user.contact_number,
                "address": user.address,
                "accommodation_type": user.accommodation_type,
                "profile_picture": student.profile_picture if student else None,
                "matric_no": student.matric_no if student else None
            }
    return {"exists": False}

@app.get("/users/pre-registered/{email}")
def check_pre_registered_email(email: str, db: Session = Depends(get_db)):
    user = db.query(models.User).filter(
        models.User.email == email,
        models.User.supabase_id.is_(None)
    ).first()
    if user:
        therapist = db.query(models.Physiotherapist).filter(models.Physiotherapist.therapist_id == user.user_id).first()
        return {
            "exists": True,
            "role": user.role,
            "username": user.username,
            "identity_number": user.identity_number,
            "gender": user.gender,
            "contact_number": user.contact_number,
            "address": user.address,
            "specialization": therapist.specialization if therapist else ""
        }
    return {"exists": False}


@app.get("/users")
def get_all_users(db: Session = Depends(get_db)):
    users = db.query(models.User).all()
    return {"users": users}

@app.get("/users/{user_id}/notifications")
def get_user_notifications(user_id: int, db: Session = Depends(get_db)):
    from datetime import datetime, timedelta
    notifications = []
    
    # 1. Chat Notifications
    active_sessions = db.query(models.LiveChatSession).filter(
        models.LiveChatSession.student_id == user_id,
        models.LiveChatSession.session_status.in_(['Triage', 'Active'])
    ).all()
    for session in active_sessions:
        last_log = db.query(models.ChatLog).filter(models.ChatLog.session_id == session.session_id).order_by(models.ChatLog.timestamp.desc()).first()
        if (
            last_log
            and last_log.sender_id is not None
            and last_log.sender_id != user_id
        ):
            notifications.append({
                "notification_id": f"chat:{session.session_id}:{last_log.chat_id}",
                "type": "chat",
                "title": "New Message",
                "message": "You have a new message from the physiotherapist.",
                "reference_id": session.session_id
            })

    # 2. Rental Notifications (Approved -> Pending Collection)
    approved_rentals = db.query(models.RentalRecord).filter(
        models.RentalRecord.student_id == user_id,
        models.RentalRecord.status == 'Approved'
    ).all()
    for rental in approved_rentals:
        eq = db.query(models.Equipment).filter(models.Equipment.equipment_id == rental.equipment_id).first()
        eq_name = eq.name if eq else "Equipment"
        notifications.append({
            "notification_id": f"rental:{rental.rental_record_id}:approved",
            "type": "rental",
            "title": "Rental Approved",
            "message": f"Your request for {eq_name} is approved. Ready for collection!",
            "reference_id": rental.rental_record_id
        })

    # 3. Appointment Notifications (Next 48h)
    now = datetime.now()
    two_days_later = now + timedelta(hours=48)
    upcoming_appointments = db.query(models.Appointment).filter(
        models.Appointment.student_id == user_id,
        models.Appointment.status == 'Scheduled',
        models.Appointment.schedule_time >= now,
        models.Appointment.schedule_time <= two_days_later
    ).all()
    for appt in upcoming_appointments:
        notifications.append({
            "notification_id": f"appointment:{appt.appointment_id}",
            "type": "appointment",
            "title": "Upcoming Appointment",
            "message": f"You have an appointment on {appt.schedule_time.strftime('%b %d, %Y at %I:%M %p')}.",
            "reference_id": appt.appointment_id
        })

    # 4. Physiotherapist-assigned exercise notifications
    assigned_exercises = db.query(
        models.PrescribedExercise,
        models.Exercise.name
    ).join(
        models.Appointment,
        models.PrescribedExercise.appointment_id == models.Appointment.appointment_id
    ).join(
        models.Exercise,
        models.PrescribedExercise.exercise_id == models.Exercise.exercise_id
    ).filter(
        models.Appointment.student_id == user_id
    ).all()
    for prescribed, exercise_name in assigned_exercises:
        notifications.append({
            "notification_id": f"assigned:{prescribed.prescribed_exercise_id}",
            "type": "exercise",
            "title": "Exercise Assigned",
            "message": f"Your physiotherapist assigned {exercise_name} to you.",
            "reference_id": prescribed.prescribed_exercise_id
        })

    # 5. Patient-scheduled exercise notifications
    scheduled_exercises = db.query(
        models.SessionLog,
        models.Exercise.name
    ).join(
        models.Exercise,
        models.SessionLog.exercise_id == models.Exercise.exercise_id
    ).filter(
        models.SessionLog.student_id == user_id,
        models.SessionLog.status == 'Pending'
    ).all()
    for scheduled, exercise_name in scheduled_exercises:
        notifications.append({
            "notification_id": f"scheduled:{scheduled.schedule_id}",
            "type": "exercise",
            "title": "Exercise Scheduled",
            "message": (
                f"{exercise_name} is scheduled for "
                f"{scheduled.completion_date.strftime('%b %d, %Y at %I:%M %p')}."
            ),
            "reference_id": scheduled.schedule_id
        })

    read_keys = {
        key for (key,) in db.query(models.NotificationRead.notification_key).filter(
            models.NotificationRead.user_id == user_id
        ).all()
    }
    unread_notifications = [
        notification for notification in notifications
        if notification["notification_id"] not in read_keys
    ]
    return {"notifications": unread_notifications}


class NotificationReadRequest(BaseModel):
    notification_id: str


@app.post("/users/{user_id}/notifications/read")
def mark_notification_read(
    user_id: int,
    request: NotificationReadRequest,
    db: Session = Depends(get_db)
):
    if not request.notification_id or len(request.notification_id) > 150:
        raise HTTPException(status_code=400, detail="Invalid notification ID")

    existing = db.query(models.NotificationRead).filter(
        models.NotificationRead.user_id == user_id,
        models.NotificationRead.notification_key == request.notification_id
    ).first()
    if not existing:
        db.add(models.NotificationRead(
            user_id=user_id,
            notification_key=request.notification_id
        ))
        db.commit()
    return {"status": "success"}


@app.get("/physio/{physio_id}/notifications")
def get_physio_notifications(physio_id: int, db: Session = Depends(get_db)):
    from datetime import timedelta

    physio = db.query(models.Physiotherapist).filter(
        models.Physiotherapist.therapist_id == physio_id
    ).first()
    if not physio:
        raise HTTPException(status_code=403, detail="Physiotherapist access required")

    patient_ids = {
        student_id for (student_id,) in db.query(models.Appointment.student_id).filter(
            models.Appointment.therapist_id == physio_id
        ).distinct().all()
    }
    notifications = []

    active_chats = db.query(models.LiveChatSession).filter(
        models.LiveChatSession.therapist_id == physio_id,
        models.LiveChatSession.session_status == "Active"
    ).all()
    for session in active_chats:
        last_incoming = db.query(models.ChatLog).filter(
            models.ChatLog.session_id == session.session_id,
            models.ChatLog.sender_id == session.student_id
        ).order_by(models.ChatLog.chat_id.desc()).first()
        receipt = db.query(models.ChatReadReceipt).filter(
            models.ChatReadReceipt.user_id == physio_id,
            models.ChatReadReceipt.session_id == session.session_id
        ).first()
        if last_incoming and (
            receipt is None or receipt.last_read_chat_id < last_incoming.chat_id
        ):
            student = db.query(models.User).filter(
                models.User.user_id == session.student_id
            ).first()
            notifications.append({
                "notification_id": f"physio-chat:{session.session_id}:{last_incoming.chat_id}",
                "type": "chat",
                "title": "New Patient Message",
                "message": f"{student.username if student else 'A patient'} sent you a message.",
                "reference_id": session.session_id
            })

    if patient_ids:
        pending_rentals = db.query(
            models.RentalRecord,
            models.User.username,
            models.Equipment.name
        ).join(
            models.User, models.RentalRecord.student_id == models.User.user_id
        ).join(
            models.Equipment,
            models.RentalRecord.equipment_id == models.Equipment.equipment_id
        ).filter(
            models.RentalRecord.student_id.in_(patient_ids),
            models.RentalRecord.status == "Pending"
        ).all()
        for rental, student_name, equipment_name in pending_rentals:
            notifications.append({
                "notification_id": f"physio-rental:{rental.rental_record_id}:pending",
                "type": "rental",
                "title": "New Rental Request",
                "message": f"{student_name} requested {equipment_name}.",
                "reference_id": rental.rental_record_id
            })

        recent_sessions = db.query(
            models.SessionLog,
            models.User.username,
            models.Exercise.name
        ).join(
            models.User, models.SessionLog.student_id == models.User.user_id
        ).join(
            models.Exercise,
            models.SessionLog.exercise_id == models.Exercise.exercise_id
        ).filter(
            models.SessionLog.student_id.in_(patient_ids),
            models.SessionLog.status == "Completed",
            models.SessionLog.completion_date >= datetime.utcnow() - timedelta(days=7)
        ).order_by(models.SessionLog.completion_date.desc()).limit(50).all()
        for session, student_name, exercise_name in recent_sessions:
            notifications.append({
                "notification_id": f"physio-exercise:{session.schedule_id}:completed",
                "type": "exercise",
                "title": "Exercise Completed",
                "message": f"{student_name} completed {exercise_name}.",
                "reference_id": session.schedule_id
            })

        upcoming_appointments = db.query(
            models.Appointment,
            models.User.username
        ).join(
            models.User, models.Appointment.student_id == models.User.user_id
        ).filter(
            models.Appointment.therapist_id == physio_id,
            models.Appointment.status == "Scheduled",
            models.Appointment.schedule_time >= datetime.utcnow()
        ).order_by(models.Appointment.schedule_time).all()
        for appointment, student_name in upcoming_appointments:
            notifications.append({
                "notification_id": f"physio-appointment:{appointment.appointment_id}:scheduled",
                "type": "appointment",
                "title": "Upcoming Appointment",
                "message": (
                    f"Appointment with {student_name} on "
                    f"{appointment.schedule_time.strftime('%b %d, %Y at %I:%M %p')}."
                ),
                "reference_id": appointment.appointment_id
            })

    read_keys = {
        key for (key,) in db.query(models.NotificationRead.notification_key).filter(
            models.NotificationRead.user_id == physio_id
        ).all()
    }
    return {
        "notifications": [
            notification for notification in notifications
            if notification["notification_id"] not in read_keys
        ]
    }

@app.get("/students")
def get_all_students(db: Session = Depends(get_db)):
    students = db.query(models.Student).all()
    return {"students": students}

@app.get("/physiotherapists")
def get_all_physiotherapists(db: Session = Depends(get_db)):
    therapists = db.query(models.Physiotherapist).all()
    return {"physiotherapists": therapists}

@app.get("/categories")
def get_all_categories(db: Session = Depends(get_db)):
    categories = db.query(models.Category).all()
    return {"categories": categories}

@app.get("/equipment")
def get_all_equipment(db: Session = Depends(get_db)):
    equipment = db.query(models.Equipment).all()
    eq_cats = db.query(models.Equipment_Category).all()
    
    eq_cat_map = {}
    for ec in eq_cats:
        if ec.equipment_id not in eq_cat_map:
            eq_cat_map[ec.equipment_id] = []
        eq_cat_map[ec.equipment_id].append(ec.category_id)
        
    result = []
    for eq in equipment:
        result.append({
            "equipment_id": eq.equipment_id,
            "name": eq.name,
            "description": eq.description,
            "stock": eq.stock,
            "image": eq.image,
            "category_ids": eq_cat_map.get(eq.equipment_id, [])
        })
        
    return {"equipment": result}

@app.get("/rental_reasons")
def get_all_rental_reasons(db: Session = Depends(get_db)):
    reasons = db.query(models.RentalReason).all()
    return {"rental_reasons": reasons}

class PhysiotherapistCreate(BaseModel):
    email: str
    username: str
    identity_number: str
    contact_number: str
    gender: str
    address: str
    specialization: str

class PhysiotherapistUpdate(BaseModel):
    username: Optional[str] = None
    identity_number: Optional[str] = None
    contact_number: Optional[str] = None
    gender: Optional[str] = None
    address: Optional[str] = None
    specialization: Optional[str] = None

@app.get("/admin/physiotherapists")
def get_admin_physiotherapists(db: Session = Depends(get_db)):
    physios = db.query(models.User).filter(models.User.role == 'P').all()
    result = []
    for p in physios:
        therapist = db.query(models.Physiotherapist).filter(models.Physiotherapist.therapist_id == p.user_id).first()
        result.append({
            "user_id": p.user_id,
            "supabase_id": p.supabase_id,
            "username": p.username,
            "email": p.email,
            "identity_number": p.identity_number,
            "gender": p.gender,
            "contact_number": p.contact_number,
            "address": p.address,
            "specialization": therapist.specialization if therapist else "",
        })
    return {"physiotherapists": result}

@app.post("/admin/physiotherapists")
def create_admin_physiotherapist(data: PhysiotherapistCreate, db: Session = Depends(get_db)):
    # Check if email is already in use
    existing = db.query(models.User).filter(models.User.email == data.email).first()
    if existing:
        raise HTTPException(status_code=400, detail="User with this email already exists")
        
    new_user = models.User(
        supabase_id=None,
        username=data.username,
        identity_number=data.identity_number,
        email=data.email,
        gender=data.gender,
        contact_number=data.contact_number,
        address=data.address,
        role='P'
    )
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    
    new_therapist = models.Physiotherapist(
        therapist_id=new_user.user_id,
        specialization=data.specialization
    )
    db.add(new_therapist)
    db.commit()
    
    return {"message": "Physiotherapist pre-registered successfully", "user_id": new_user.user_id}

@app.put("/admin/physiotherapists/{user_id}")
def update_admin_physiotherapist(user_id: int, data: PhysiotherapistUpdate, db: Session = Depends(get_db)):
    user = db.query(models.User).filter(models.User.user_id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="Physiotherapist not found")
    if user.role != 'P':
        raise HTTPException(status_code=400, detail="User is not a physiotherapist")
        
    if data.username is not None:
        user.username = data.username
    if data.identity_number is not None:
        user.identity_number = data.identity_number
    if data.contact_number is not None:
        user.contact_number = data.contact_number
    if data.gender is not None:
        user.gender = data.gender
    if data.address is not None:
        user.address = data.address
        
    therapist = db.query(models.Physiotherapist).filter(models.Physiotherapist.therapist_id == user_id).first()
    if therapist:
        if data.specialization is not None:
            therapist.specialization = data.specialization
    else:
        if data.specialization is not None:
            new_therapist = models.Physiotherapist(
                therapist_id=user_id,
                specialization=data.specialization
            )
            db.add(new_therapist)
            
    db.commit()
    return {"message": "Physiotherapist updated successfully"}

@app.delete("/admin/physiotherapists/{user_id}")
def delete_admin_physiotherapist(user_id: int, db: Session = Depends(get_db)):
    user = db.query(models.User).filter(models.User.user_id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="Physiotherapist not found")
    if user.role != 'P':
        raise HTTPException(status_code=400, detail="User is not a physiotherapist")
        
    # Check if they have active appointments
    appointments_count = db.query(models.Appointment).filter(models.Appointment.therapist_id == user_id).count()
    if appointments_count > 0:
         raise HTTPException(status_code=400, detail="Cannot delete physiotherapist: they have active appointments")
         
    # Delete from Physiotherapist and User
    therapist = db.query(models.Physiotherapist).filter(models.Physiotherapist.therapist_id == user_id).first()
    if therapist:
        db.delete(therapist)
    db.delete(user)
    db.commit()
    return {"message": "Physiotherapist deleted successfully"}

@app.get("/admin/rentals")
def get_admin_rentals(db: Session = Depends(get_db)):
    rentals = db.query(models.RentalRecord).all()
    result = []
    for r in rentals:
        student_user = db.query(models.User).filter(models.User.user_id == r.student_id).first()
        student = db.query(models.Student).filter(
            models.Student.student_id == r.student_id
        ).first()
        equipment = db.query(models.Equipment).filter(models.Equipment.equipment_id == r.equipment_id).first()
        reason = db.query(models.RentalReason).filter(models.RentalReason.rental_reason_id == r.rental_reason_id).first()
        
        result.append({
            "rental_record_id": r.rental_record_id,
            "student_id": r.student_id,
            "student_name": student_user.username if student_user else "Unknown",
            "matric_no": student.matric_no if student else None,
            "admin_id": r.admin_id,
            "equipment_id": r.equipment_id,
            "equipment_name": equipment.name if equipment else "Unknown",
            "rental_reason": reason.description if reason else "Unknown",
            "custom_reason": r.custom_reason,
            "collection_method": r.collection_method,
            "proof_of_collection": r.proof_of_collection,
            "collection_date": r.collection_date.isoformat() if r.collection_date else None,
            "return_date": r.return_date,
            "status": r.status,
            "rental_duration": r.rental_duration,
            "return_status": r.return_status,
            "proof_of_status": r.proof_of_status
        })
    return {"rentals": result}

class RentalStatusUpdate(BaseModel):
    status: str
    admin_id: int
    return_status: Optional[str] = None
    proof_of_collection: Optional[str] = None
    proof_of_status: Optional[str] = None
    
@app.put("/admin/rentals/{rental_record_id}/status")
def update_rental_status(rental_record_id: int, update_data: RentalStatusUpdate, db: Session = Depends(get_db)):
    admin = db.query(models.Admin).filter(
        models.Admin.admin_id == update_data.admin_id
    ).first()
    if not admin:
        raise HTTPException(status_code=403, detail="Admin access required")

    record = db.query(models.RentalRecord).filter(models.RentalRecord.rental_record_id == rental_record_id).first()
    if not record:
        raise HTTPException(status_code=404, detail="Rental record not found")

    if update_data.status == "Active":
        if record.status != "Approved":
            raise HTTPException(status_code=400, detail="Only approved rentals can be collected")
        if not update_data.proof_of_collection:
            raise HTTPException(status_code=400, detail="Collection photo is required")
    elif update_data.status == "Returned":
        if record.status != "Active":
            raise HTTPException(status_code=400, detail="Only active rentals can be returned")
        if update_data.return_status not in {"Good", "Damaged", "Lost"}:
            raise HTTPException(status_code=400, detail="Return condition is required")
        if not update_data.proof_of_status:
            raise HTTPException(status_code=400, detail="Return photo is required")
        record.return_date = datetime.utcnow()
    else:
        raise HTTPException(
            status_code=403,
            detail="Admins may only confirm collection or return"
        )

    record.status = update_data.status
    record.admin_id = update_data.admin_id
    if update_data.return_status:
        record.return_status = update_data.return_status
    if update_data.proof_of_collection:
        record.proof_of_collection = update_data.proof_of_collection
    if update_data.proof_of_status:
        record.proof_of_status = update_data.proof_of_status
        
    db.commit()
    return {"message": "Rental status updated successfully"}

class EquipmentCreate(BaseModel):
    name: str
    description: Optional[str] = None
    stock: int
    admin_id: Optional[int] = None
    image: Optional[str] = None

@app.post("/admin/equipment")
def create_equipment(eq: EquipmentCreate, db: Session = Depends(get_db)):
    new_eq = models.Equipment(
        name=eq.name,
        description=eq.description,
        stock=eq.stock,
        admin_id=eq.admin_id,
        image=eq.image
    )
    db.add(new_eq)
    db.commit()
    db.refresh(new_eq)
    return {"message": "Equipment added successfully", "equipment_id": new_eq.equipment_id}

@app.put("/admin/equipment/{equipment_id}")
def update_equipment(equipment_id: int, eq: EquipmentCreate, db: Session = Depends(get_db)):
    equipment = db.query(models.Equipment).filter(models.Equipment.equipment_id == equipment_id).first()
    if not equipment:
        raise HTTPException(status_code=404, detail="Equipment not found")
        
    equipment.name = eq.name
    equipment.description = eq.description
    equipment.stock = eq.stock
    if eq.image is not None:
        equipment.image = eq.image
    if eq.admin_id is not None:
        equipment.admin_id = eq.admin_id
        
    db.commit()
    return {"message": "Equipment updated successfully"}

@app.delete("/admin/equipment/{equipment_id}")
def delete_equipment(equipment_id: int, db: Session = Depends(get_db)):
    equipment = db.query(models.Equipment).filter(models.Equipment.equipment_id == equipment_id).first()
    if not equipment:
        raise HTTPException(status_code=404, detail="Equipment not found")
        
    db.delete(equipment)
    db.commit()
    return {"message": "Equipment deleted successfully"}

@app.get("/cancellation_reasons")
def get_all_cancellation_reasons(db: Session = Depends(get_db)):
    reasons = db.query(models.CancellationReason).all()
    return {"cancellation_reasons": reasons}

@app.get("/appointments")
def get_all_appointments(db: Session = Depends(get_db)):
    appointments = db.query(models.Appointment).all()
    return {"appointments": appointments}


@app.get("/exercises")
def get_all_exercises(db: Session = Depends(get_db)):
    exercises = db.query(models.Exercise).all()
    result = []
    for ex in exercises:
        disciplines = db.query(models.Discipline.description).join(
            models.ExerciseDiscipline, 
            models.Discipline.discipline_id == models.ExerciseDiscipline.discipline_id
        ).filter(models.ExerciseDiscipline.exercise_id == ex.exercise_id).all()
        
        discipline_list = [d[0] for d in disciplines]
        
        result.append({
            "exercise_id": ex.exercise_id,
            "name": ex.name,
            "description": ex.description,
            "disciplines": discipline_list,
            "reference_joint_angle": ex.reference_joint_angle,
            "video_url": ex.video_url,
            "requires_ai": ex.requires_ai,
            "ai_type": ex.ai_type
        })
    return {"exercises": result}

@app.get("/students/{student_id}/prescribed_exercises")
def get_prescribed_exercises(student_id: int, db: Session = Depends(get_db)):
    active_appointment = db.query(models.Appointment).filter(
        models.Appointment.student_id == student_id,
        models.Appointment.prescription != None
    ).order_by(models.Appointment.schedule_time.desc()).first()
    
    if not active_appointment:
        return {"exercises": []}
        
    prescribed = db.query(models.PrescribedExercise).filter(
        models.PrescribedExercise.appointment_id == active_appointment.appointment_id
    ).all()
    
    result = []
    today = datetime.now().date()
    for pe in prescribed:
        assigned_days = max(pe.assigned_days or 1, 1)
        assigned_at = pe.assigned_at or active_appointment.schedule_time
        plan_start = assigned_at.date() if assigned_at else today
        plan_end = plan_start + timedelta(days=assigned_days - 1)
        # A prescription is part of the student's daily routine from its
        # start date through the final assigned day, inclusive.
        if today > plan_end:
            continue
        plan_day = 0 if today < plan_start else (today - plan_start).days + 1
        days_remaining = (
            assigned_days
            if today < plan_start
            else (plan_end - today).days + 1
        )
        ex = db.query(models.Exercise).filter(models.Exercise.exercise_id == pe.exercise_id).first()
        if ex:
            disciplines = db.query(models.Discipline.description).join(
                models.ExerciseDiscipline, 
                models.Discipline.discipline_id == models.ExerciseDiscipline.discipline_id
            ).filter(models.ExerciseDiscipline.exercise_id == ex.exercise_id).all()
            
            discipline_list = [d[0] for d in disciplines]
            
            result.append({
                "exercise_id": ex.exercise_id,
                "name": ex.name,
                "description": ex.description,
                "disciplines": discipline_list,
                "reference_joint_angle": ex.reference_joint_angle,
                "video_url": ex.video_url,
                "requires_ai": ex.requires_ai,
                "ai_type": ex.ai_type,
                "prescribed_exercise_id": pe.prescribed_exercise_id,
                "assigned_sets": pe.assigned_sets,
                "assigned_duration": pe.assigned_duration,
                "assigned_reps": pe.assigned_reps,
                "assigned_days": assigned_days,
                "assigned_tracking_mode": pe.assigned_tracking_mode,
                "assigned_date": assigned_at.isoformat() if assigned_at else None,
                "plan_day": plan_day,
                "days_remaining": days_remaining,
                "plan_progress": min(plan_day / assigned_days, 1.0),
                "plan_end_date": plan_end.isoformat()
            })
    return {"exercises": result}

@app.get("/prescribed_exercises")
def get_all_prescribed_exercises(db: Session = Depends(get_db)):
    prescribed = db.query(models.PrescribedExercise).all()
    return {"prescribed_exercises": prescribed}

class ScheduleExerciseRequest(BaseModel):
    exercise_id: int
    scheduled_date: datetime

@app.post("/students/{student_id}/scheduled_exercises")
def schedule_exercise(student_id: int, request: ScheduleExerciseRequest, db: Session = Depends(get_db)):
    new_scheduled = models.SessionLog(
        student_id=student_id,
        exercise_id=request.exercise_id,
        completion_date=request.scheduled_date,
        status="Pending",
        session_origin="Self-selected"
    )
    db.add(new_scheduled)
    db.commit()
    db.refresh(new_scheduled)
    return {"message": "Exercise scheduled successfully", "schedule_id": new_scheduled.schedule_id}

@app.get("/students/{student_id}/scheduled_exercises")
def get_scheduled_exercises(student_id: int, db: Session = Depends(get_db)):
    scheduled = db.query(models.SessionLog).filter(
        models.SessionLog.student_id == student_id,
        models.SessionLog.status == "Pending"
    ).order_by(models.SessionLog.completion_date.asc()).all()
    
    result = []
    for se in scheduled:
        ex = db.query(models.Exercise).filter(models.Exercise.exercise_id == se.exercise_id).first()
        if ex:
            disciplines = db.query(models.Discipline.description).join(
                models.ExerciseDiscipline, 
                models.Discipline.discipline_id == models.ExerciseDiscipline.discipline_id
            ).filter(models.ExerciseDiscipline.exercise_id == ex.exercise_id).all()
            
            discipline_list = [d[0] for d in disciplines]
            
            result.append({
                "schedule_id": se.schedule_id,
                "exercise_id": ex.exercise_id,
                "name": ex.name,
                "description": ex.description,
                "disciplines": discipline_list,
                "reference_joint_angle": ex.reference_joint_angle,
                "video_url": ex.video_url,
                "requires_ai": ex.requires_ai,
                "ai_type": ex.ai_type,
                "scheduled_date": se.completion_date.isoformat(),
                "status": se.status
            })
    return {"scheduled_exercises": result}

@app.get("/students/{student_id}/completed_exercises")
def get_completed_exercises(student_id: int, db: Session = Depends(get_db)):
    completed = db.query(models.SessionLog).filter(
        models.SessionLog.student_id == student_id,
        models.SessionLog.status == "Completed"
    ).order_by(models.SessionLog.completion_date.desc()).all()

    result = []
    for session in completed:
        ex = db.query(models.Exercise).filter(
            models.Exercise.exercise_id == session.exercise_id
        ).first()
        if not ex:
            continue

        disciplines = db.query(models.Discipline.description).join(
            models.ExerciseDiscipline,
            models.Discipline.discipline_id == models.ExerciseDiscipline.discipline_id
        ).filter(
            models.ExerciseDiscipline.exercise_id == ex.exercise_id
        ).all()

        result.append({
            "schedule_id": session.schedule_id,
            "exercise_id": ex.exercise_id,
            "name": ex.name,
            "description": ex.description,
            "disciplines": [discipline[0] for discipline in disciplines],
            "completion_date": session.completion_date.isoformat() if session.completion_date else None,
            "completed_reps": session.completed_reps,
            "duration_seconds": session.duration_seconds,
            "completed_sets": session.completed_sets,
            "planned_sets": session.planned_sets,
            "accuracy_score": session.accuracy_score,
            "pain_before": session.pain_before,
            "pain_after": session.pain_after,
            "session_origin": session.session_origin,
            "status": session.status
        })

    return {"completed_exercises": result}

class UpdateScheduledExerciseRequest(BaseModel):
    status: str

@app.put("/scheduled_exercises/{schedule_id}/status")
def update_scheduled_exercise_status(schedule_id: int, request: UpdateScheduledExerciseRequest, db: Session = Depends(get_db)):
    se = db.query(models.SessionLog).filter(models.SessionLog.schedule_id == schedule_id).first()
    if not se:
        raise HTTPException(status_code=404, detail="Scheduled exercise not found")
        
    se.status = request.status
    db.commit()
    return {"message": "Status updated successfully"}

@app.get("/ai_feedback")
def get_all_ai_feedback(db: Session = Depends(get_db)):
    feedback = db.query(models.AIFeedback).all()
    return {"ai_feedback": feedback}

@app.get("/live_chat_sessions")
def get_all_live_chat_sessions(db: Session = Depends(get_db)):
    sessions = db.query(models.LiveChatSession).all()
    return {"live_chat_sessions": sessions}

@app.get("/chat_logs")
def get_all_chat_logs(db: Session = Depends(get_db)):
    logs = db.query(models.ChatLog).all()
    return {"chat_logs": logs}

def generate_frames():
    # 0 is usually the default built-in webcam
    cap = cv2.VideoCapture(0)
    detector = PoseDetector()

    while True:
        success, img = cap.read()
        if not success:
            break
            
        img = cv2.flip(img, 1)

        # Feed the image into the AI to find the pose and draw the skeleton
        img = detector.find_pose(img, draw=True)
        
        # Extract all the landmark coordinates
        lm_list = detector.get_position(img)
        
        # Calculate the Right Arm (Elbow) Angle
        if len(lm_list) != 0:
            shoulder = lm_list[12][1:3]
            elbow = lm_list[14][1:3]
            wrist = lm_list[16][1:3]
            
            angle = calculate_angle(shoulder, elbow, wrist)
            
            cv2.putText(img, f"{int(angle)} deg", (elbow[0] + 15, elbow[1] - 15), 
                        cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 0, 255), 3)

        ret, buffer = cv2.imencode('.jpg', img)
        frame = buffer.tobytes()
        yield (b'--frame\r\n'
               b'Content-Type: image/jpeg\r\n\r\n' + frame + b'\r\n')

@app.get("/video_feed")
def video_feed():
    return StreamingResponse(generate_frames(), media_type="multipart/x-mixed-replace; boundary=frame")

class StartChatReq(BaseModel):
    user_id: int
    message: str

def assign_physio(db: Session, session_id: int, discipline: str):
    # Find physio with matching specialization
    physio = db.query(models.Physiotherapist).filter(models.Physiotherapist.specialization.ilike(f"%{discipline}%")).first()
    if not physio:
        physio = db.query(models.Physiotherapist).first()
        
    if physio:
        session = db.query(models.LiveChatSession).filter(models.LiveChatSession.session_id == session_id).first()
        if session:
            session.therapist_id = physio.therapist_id
            db.commit()

def check_posture_integration(db: Session, student_id: int, auto_reply: str) -> str:
    # Phase 6: Link AI Posture feedback to the triage output
    feedback = db.query(models.AIFeedback)\
        .join(models.PrescribedExercise, models.AIFeedback.prescribed_exercise_id == models.PrescribedExercise.prescribed_exercise_id)\
        .join(models.Appointment, models.PrescribedExercise.appointment_id == models.Appointment.appointment_id)\
        .filter(models.Appointment.student_id == student_id)\
        .order_by(models.AIFeedback.timestamp.desc())\
        .first()
    
    if feedback and feedback.accuracy_score is not None and feedback.accuracy_score < 70:
        auto_reply += "\n\n(AI Posture Alert: We noticed your recent exercise accuracy was low. This movement issue may be contributing to your current symptoms. Your therapist has been notified.)"
    return auto_reply

@app.post("/chat/start")
def start_chat(req: StartChatReq, db: Session = Depends(get_db)):
    # 1. Triage the message
    updated_state, auto_reply, session_status = chatbot_instance.process_message(req.message, None)
    
    if session_status == "Active":
        auto_reply = check_posture_integration(db, req.user_id, auto_reply)

    # 2. Create the session
    new_session = models.LiveChatSession(
        student_id=req.user_id,
        subject="Initial Triage",
        discipline=updated_state.get("discipline"),
        triage_data=updated_state,
        session_status=session_status
    )
    db.add(new_session)
    db.commit()
    db.refresh(new_session)
    
    # 3. Create the user's message log
    user_log = models.ChatLog(
        session_id=new_session.session_id,
        sender_id=req.user_id,
        content=req.message
    )
    db.add(user_log)
    
    # 4. Create the system's auto-reply log
    system_log = models.ChatLog(
        session_id=new_session.session_id,
        sender_id=None,
        content=auto_reply
    )
    db.add(system_log)
    db.commit()
    
    # Phase 4: Assign physio
    if session_status == "Active" and updated_state.get("discipline"):
        assign_physio(db, new_session.session_id, updated_state.get("discipline"))
    
    return {
        "session_id": new_session.session_id,
        "discipline": updated_state.get("discipline"),
        "auto_reply": auto_reply
    }

class SendMessageReq(BaseModel):
    session_id: int
    user_id: int
    message: str


class BookAppointmentReq(BaseModel):
    student_id: int
    therapist_id: int
    schedule_time: datetime

class CancelAppointmentReq(BaseModel):
    reason_id: int
    other_reason: Optional[str] = None

@app.post("/chat/send")
def send_message(req: SendMessageReq, db: Session = Depends(get_db)):
    user_log = models.ChatLog(
        session_id=req.session_id,
        sender_id=req.user_id,
        content=req.message
    )
    db.add(user_log)
    db.commit()
    
    # Phase 1 & 2: Stateful Multi-turn triage
    session = db.query(models.LiveChatSession).filter(models.LiveChatSession.session_id == req.session_id).first()
    if session and session.session_status == "Triage":
        updated_state, auto_reply, new_status = chatbot_instance.process_message(req.message, session.triage_data)
        
        if new_status == "Active":
            auto_reply = check_posture_integration(db, req.user_id, auto_reply)

        session.triage_data = updated_state
        flag_modified(session, "triage_data")
        session.session_status = new_status
        session.discipline = updated_state.get("discipline")
        
        system_log = models.ChatLog(
            session_id=req.session_id,
            sender_id=None,
            content=auto_reply
        )
        db.add(system_log)
        db.commit()
        
        # Phase 4: Assign physio
        if new_status == "Active" and session.discipline:
            assign_physio(db, session.session_id, session.discipline)
            
    return {"status": "success"}

@app.get("/physio/chats/{physio_id}")
def get_physio_chats(physio_id: int, db: Session = Depends(get_db)):
    chats = db.query(
        models.LiveChatSession.session_id,
        models.LiveChatSession.subject,
        models.LiveChatSession.discipline,
        models.LiveChatSession.session_status,
        models.LiveChatSession.triage_data,
        models.LiveChatSession.student_id,
        models.LiveChatSession.teleconference_room,
        models.LiveChatSession.teleconference_status,
        models.LiveChatSession.consultation_prescription,
        models.LiveChatSession.created_at,
        models.User.username.label("student_name")
    ).join(
        models.User, models.LiveChatSession.student_id == models.User.user_id
    ).filter(
        models.LiveChatSession.therapist_id == physio_id
    ).order_by(
        models.LiveChatSession.created_at.desc()
    ).all()
    
    result = []
    for chat in chats:
        last_incoming = db.query(models.ChatLog).filter(
            models.ChatLog.session_id == chat.session_id,
            models.ChatLog.sender_id.isnot(None),
            models.ChatLog.sender_id != physio_id
        ).order_by(models.ChatLog.chat_id.desc()).first()
        receipt = db.query(models.ChatReadReceipt).filter(
            models.ChatReadReceipt.user_id == physio_id,
            models.ChatReadReceipt.session_id == chat.session_id
        ).first()
        has_unread = bool(
            chat.session_status == "Active"
            and last_incoming
            and (
                receipt is None
                or receipt.last_read_chat_id < last_incoming.chat_id
            )
        )
            
        result.append({
            "session_id": chat.session_id,
            "subject": chat.subject,
            "discipline": chat.discipline,
            "session_status": chat.session_status,
            "triage_data": chat.triage_data,
            "student_id": chat.student_id,
            "teleconference_room": chat.teleconference_room,
            "teleconference_status": chat.teleconference_status,
            "consultation_prescription": chat.consultation_prescription,
            "created_at": chat.created_at,
            "student_name": chat.student_name,
            "has_unread": has_unread
        })
    return {"chats": result}


class StartTeleconferenceReq(BaseModel):
    physio_id: int


class RespondTeleconferenceReq(BaseModel):
    user_id: int
    accepted: bool


@app.post("/physio/chats/{session_id}/teleconference")
def start_chat_teleconference(
    session_id: int,
    req: StartTeleconferenceReq,
    db: Session = Depends(get_db),
):
    session = db.query(models.LiveChatSession).filter(
        models.LiveChatSession.session_id == session_id,
        models.LiveChatSession.therapist_id == req.physio_id,
        models.LiveChatSession.session_status == "Active",
    ).first()
    if not session:
        raise HTTPException(status_code=403, detail="Active chat is not assigned to this physiotherapist")

    room = f"rehab-ai-chat-{secrets.token_hex(16)}"
    session.teleconference_room = room
    session.teleconference_status = "Invited"
    db.add(models.ChatLog(
        session_id=session_id,
        sender_id=req.physio_id,
        content=f"[TELECONFERENCE_INVITE:{room}]",
    ))
    db.commit()
    return {"status": "Invited", "meeting_room": room}


@app.post("/chats/{session_id}/teleconference/respond")
def respond_chat_teleconference(
    session_id: int,
    req: RespondTeleconferenceReq,
    db: Session = Depends(get_db),
):
    session = db.query(models.LiveChatSession).filter(
        models.LiveChatSession.session_id == session_id,
        models.LiveChatSession.student_id == req.user_id,
        models.LiveChatSession.session_status == "Active",
    ).first()
    if not session or not session.teleconference_room:
        raise HTTPException(status_code=404, detail="Video consultation invitation not found")

    session.teleconference_status = "Accepted" if req.accepted else "Declined"
    response_text = (
        "Video consultation accepted."
        if req.accepted
        else "Video consultation declined."
    )
    db.add(models.ChatLog(
        session_id=session_id,
        sender_id=req.user_id,
        content=response_text,
    ))
    db.commit()
    return {
        "status": session.teleconference_status,
        "meeting_room": session.teleconference_room if req.accepted else None,
    }


@app.post("/physio/chats/{session_id}/read")
def mark_physio_chat_read(
    session_id: int,
    physio_id: int,
    db: Session = Depends(get_db)
):
    session = db.query(models.LiveChatSession).filter(
        models.LiveChatSession.session_id == session_id,
        models.LiveChatSession.therapist_id == physio_id
    ).first()
    if not session:
        raise HTTPException(status_code=403, detail="Chat is not assigned to this physiotherapist")

    last_incoming = db.query(models.ChatLog).filter(
        models.ChatLog.session_id == session_id,
        models.ChatLog.sender_id.isnot(None),
        models.ChatLog.sender_id != physio_id
    ).order_by(models.ChatLog.chat_id.desc()).first()
    if not last_incoming:
        return {"status": "success"}

    receipt = db.query(models.ChatReadReceipt).filter(
        models.ChatReadReceipt.user_id == physio_id,
        models.ChatReadReceipt.session_id == session_id
    ).first()
    if receipt:
        receipt.last_read_chat_id = last_incoming.chat_id
        receipt.read_at = datetime.utcnow()
    else:
        db.add(models.ChatReadReceipt(
            user_id=physio_id,
            session_id=session_id,
            last_read_chat_id=last_incoming.chat_id
        ))
    db.commit()
    return {"status": "success"}

@app.put("/physio/chats/{session_id}/close")
def close_chat(session_id: int, db: Session = Depends(get_db)):
    chat = db.query(models.LiveChatSession).filter(models.LiveChatSession.session_id == session_id).first()
    if not chat:
        raise HTTPException(status_code=404, detail="Chat not found")
    chat.session_status = "Closed"
    db.commit()
    return {"status": "success", "message": "Chat closed successfully"}

@app.get("/physio/patients/{physio_id}")
def get_physio_patients(physio_id: int, db: Session = Depends(get_db)):
    students = db.query(models.User.user_id, models.User.username, models.User.email).join(
        models.Appointment, models.User.user_id == models.Appointment.student_id
    ).filter(models.Appointment.therapist_id == physio_id).distinct().all()
    
    result = []
    for s in students:
        presc = db.query(models.Appointment).filter(
            models.Appointment.student_id == s.user_id,
            models.Appointment.therapist_id == physio_id,
            models.Appointment.prescription != None
        ).order_by(models.Appointment.schedule_time.desc()).first()
        
        exercises = []
        if presc:
            pexs = db.query(models.PrescribedExercise, models.Exercise.name).join(
                models.Exercise, models.PrescribedExercise.exercise_id == models.Exercise.exercise_id
            ).filter(models.PrescribedExercise.appointment_id == presc.appointment_id).all()
            for px, ename in pexs:
                exercises.append({
                    "id": px.prescribed_exercise_id,
                    "name": ename,
                    "assigned_sets": px.assigned_sets,
                    "assigned_duration": px.assigned_duration,
                    "assigned_reps": px.assigned_reps,
                    "assigned_days": px.assigned_days,
                    "assigned_tracking_mode": px.assigned_tracking_mode,
                    "evaluation": px.evaluation
                })
                
        result.append({
            "student_id": s.user_id,
            "student_name": s.username,
            "email": s.email,
            "active_prescription": presc.prescription if presc else None,
            "exercises": exercises
        })
    return {"patients": result}

@app.get("/physio/{physio_id}/patients/{student_id}/progress")
def get_physio_patient_progress(
    physio_id: int,
    student_id: int,
    db: Session = Depends(get_db)
):
    relationship = db.query(models.Appointment).filter(
        models.Appointment.therapist_id == physio_id,
        models.Appointment.student_id == student_id
    ).first()
    if not relationship:
        raise HTTPException(status_code=404, detail="Patient is not assigned to this physiotherapist")

    student = db.query(models.User).filter(models.User.user_id == student_id).first()
    if not student:
        raise HTTPException(status_code=404, detail="Patient not found")

    # Fetch all appointments for this student and physio
    appointments = db.query(models.Appointment).filter(
        models.Appointment.therapist_id == physio_id,
        models.Appointment.student_id == student_id
    ).order_by(models.Appointment.schedule_time.desc()).all()

    appointments_data = []
    exercise_assignments = {} # For all exercises
    
    sessions = db.query(models.SessionLog).filter(
        models.SessionLog.student_id == student_id,
        models.SessionLog.status == "Completed"
    ).order_by(models.SessionLog.completion_date.desc()).all()

    session_exercise_ids = {session.exercise_id for session in sessions}
    exercise_catalog = {
        exercise.exercise_id: exercise.name
        for exercise in db.query(models.Exercise).filter(
            models.Exercise.exercise_id.in_(session_exercise_ids)
        ).all()
    } if session_exercise_ids else {}
    
    from datetime import datetime, timedelta

    for i, appt in enumerate(appointments):
        prescribed_rows = db.query(models.PrescribedExercise, models.Exercise).join(
            models.Exercise, models.PrescribedExercise.exercise_id == models.Exercise.exercise_id
        ).filter(models.PrescribedExercise.appointment_id == appt.appointment_id).all()
        
        appt_exercises = []
        appt_assigned_exercise_ids = set()
        for prescribed, exercise in prescribed_rows:
            ex_data = {
                "exercise_id": exercise.exercise_id,
                "name": exercise.name,
                "assigned_sets": prescribed.assigned_sets,
                "assigned_duration": prescribed.assigned_duration,
                "assigned_reps": prescribed.assigned_reps,
                "assigned_days": prescribed.assigned_days,
                "assigned_tracking_mode": prescribed.assigned_tracking_mode,
                "evaluation": prescribed.evaluation
            }
            appt_exercises.append(ex_data)
            appt_assigned_exercise_ids.add(exercise.exercise_id)
            exercise_assignments[exercise.exercise_id] = ex_data
            
        chat_session = db.query(models.LiveChatSession).filter(
            models.LiveChatSession.consultation_appointment_id == appt.appointment_id
        ).first()
        triage_data = chat_session.triage_data if chat_session else None

        # Determine time window for this appointment
        start_time = appt.schedule_time
        end_time = appointments[i-1].schedule_time if i > 0 else None

        appt_sessions = []
        for s in sessions:
            if not s.completion_date: continue
            if start_time and s.completion_date < start_time: continue
            if end_time and s.completion_date >= end_time: continue
            if s.exercise_id in appt_assigned_exercise_ids:
                appt_sessions.append(s)

        total_seconds = sum(s.duration_seconds or 0 for s in appt_sessions)
        accuracy_values = [s.accuracy_score for s in appt_sessions if s.accuracy_score is not None]
        pain_changes = [s.pain_before - s.pain_after for s in appt_sessions if s.pain_before is not None and s.pain_after is not None]
        
        session_days = sorted({s.completion_date.date() for s in appt_sessions}, reverse=True)
        streak = 0
        if session_days:
            streak = 1
            expected = session_days[0]
            for day in session_days[1:]:
                expected = expected - timedelta(days=1)
                if day == expected:
                    streak += 1
                elif day < expected:
                    break

        appt_summary = {
            "total_sessions": len(appt_sessions),
            "total_duration_minutes": total_seconds // 60,
            "average_accuracy": sum(accuracy_values) / len(accuracy_values) if accuracy_values else None,
            "average_pain_change": sum(pain_changes) / len(pain_changes) if pain_changes else None,
            "activity_streak": streak
        }

        reference_date = end_time.date() if end_time else datetime.utcnow().date()
        appt_weekly = []
        for days_ago in range(6, -1, -1):
            day = reference_date - timedelta(days=days_ago)
            day_sessions = [s for s in appt_sessions if s.completion_date.date() == day]
            appt_weekly.append({
                "date": day.isoformat(),
                "session_count": len(day_sessions),
                "duration_seconds": sum(s.duration_seconds or 0 for s in day_sessions)
            })
            
        appt_recent = []
        for s in appt_sessions[:20]:
            ex_info = next((e for e in appt_exercises if e['exercise_id'] == s.exercise_id), {})
            appt_recent.append({
                "session_id": s.schedule_id,
                "exercise_id": s.exercise_id,
                "exercise_name": ex_info.get("name", exercise_catalog.get(s.exercise_id, "Exercise")),
                "source": "Assigned",
                "completion_date": s.completion_date.isoformat(),
                "completed_reps": s.completed_reps,
                "duration_seconds": s.duration_seconds,
                "completed_sets": s.completed_sets,
                "accuracy_score": s.accuracy_score,
                "pain_before": s.pain_before,
                "pain_after": s.pain_after
            })

        appointments_data.append({
            "appointment_id": appt.appointment_id,
            "date": appt.schedule_time.isoformat() if appt.schedule_time else None,
            "status": appt.status,
            "prescription": appt.prescription,
            "assigned_exercises": appt_exercises,
            "triage_data": triage_data,
            "summary": appt_summary,
            "weekly_activity": appt_weekly,
            "recent_sessions": appt_recent
        })

    exercise_ids = set(exercise_assignments.keys())

    def session_origin(session):
        if session.session_origin in {"Assigned", "Self-selected"}:
            return session.session_origin
        # Backward-compatible classification for logs created before origin
        # was stored explicitly. An exercise may exist in the prescription but
        # still have been started independently from Explore. A different set
        # target is the strongest legacy signal available for that case.
        assignment = exercise_assignments.get(session.exercise_id)
        if assignment is None:
            return "Self-selected"
        if (
            session.planned_sets is not None
            and assignment["assigned_sets"] is not None
            and session.planned_sets != assignment["assigned_sets"]
        ):
            return "Self-selected"
        return "Assigned"

    assigned_sessions = [
        session for session in sessions if session_origin(session) == "Assigned"
    ]
    self_selected_sessions = [
        session for session in sessions if session_origin(session) == "Self-selected"
    ]

    total_seconds = sum(session.duration_seconds or 0 for session in sessions)
    accuracy_values = [
        session.accuracy_score for session in sessions
        if session.accuracy_score is not None
    ]
    pain_changes = [
        session.pain_before - session.pain_after for session in sessions
        if session.pain_before is not None and session.pain_after is not None
    ]

    session_days = sorted({
        session.completion_date.date() for session in sessions
        if session.completion_date is not None
    }, reverse=True)
    streak = 0
    if session_days:
        streak = 1
        expected = session_days[0]
        from datetime import timedelta
        for day in session_days[1:]:
            expected = expected - timedelta(days=1)
            if day == expected:
                streak += 1
            elif day < expected:
                break

    per_exercise = []
    for exercise_id, assignment in exercise_assignments.items():
        exercise_sessions = [
            session for session in assigned_sessions
            if session.exercise_id == exercise_id
        ]
        exercise_accuracy = [
            session.accuracy_score for session in exercise_sessions
            if session.accuracy_score is not None
        ]
        latest = exercise_sessions[0] if exercise_sessions else None
        per_exercise.append({
            **assignment,
            "source": "Assigned",
            "session_count": len(exercise_sessions),
            "total_duration_seconds": sum(
                session.duration_seconds or 0 for session in exercise_sessions
            ),
            "average_accuracy": (
                sum(exercise_accuracy) / len(exercise_accuracy)
                if exercise_accuracy else None
            ),
            "last_completed": (
                latest.completion_date.isoformat()
                if latest and latest.completion_date else None
            )
        })

    for exercise_id in sorted({
        session.exercise_id for session in self_selected_sessions
    }):
        exercise_sessions = [
            session for session in self_selected_sessions
            if session.exercise_id == exercise_id
        ]
        exercise_accuracy = [
            session.accuracy_score for session in exercise_sessions
            if session.accuracy_score is not None
        ]
        latest = exercise_sessions[0]
        per_exercise.append({
            "exercise_id": exercise_id,
            "name": exercise_catalog.get(exercise_id, "Exercise"),
            "source": "Self-selected",
            "assigned_sets": None,
            "assigned_duration": None,
            "evaluation": None,
            "session_count": len(exercise_sessions),
            "total_duration_seconds": sum(
                session.duration_seconds or 0 for session in exercise_sessions
            ),
            "average_accuracy": (
                sum(exercise_accuracy) / len(exercise_accuracy)
                if exercise_accuracy else None
            ),
            "last_completed": (
                latest.completion_date.isoformat()
                if latest.completion_date else None
            )
        })

    today = datetime.utcnow().date()
    from datetime import timedelta
    weekly_activity = []
    for days_ago in range(6, -1, -1):
        day = today - timedelta(days=days_ago)
        day_sessions = [
            session for session in sessions
            if session.completion_date and session.completion_date.date() == day
        ]
        weekly_activity.append({
            "date": day.isoformat(),
            "session_count": len(day_sessions),
            "duration_seconds": sum(
                session.duration_seconds or 0 for session in day_sessions
            )
        })

    recent_sessions = []
    for session in sessions[:20]:
        exercise = exercise_assignments.get(session.exercise_id, {})
        recent_sessions.append({
            "session_id": session.schedule_id,
            "exercise_id": session.exercise_id,
            "exercise_name": exercise.get(
                "name", exercise_catalog.get(session.exercise_id, "Exercise")
            ),
            "source": session_origin(session),
            "completion_date": (
                session.completion_date.isoformat()
                if session.completion_date else None
            ),
            "completed_reps": session.completed_reps,
            "duration_seconds": session.duration_seconds,
            "completed_sets": session.completed_sets,
            "accuracy_score": session.accuracy_score,
            "pain_before": session.pain_before,
            "pain_after": session.pain_after
        })

    student_record = db.query(models.Student).filter(models.Student.student_id == student.user_id).first()

    return {
        "patient": {
            "student_id": student.user_id,
            "student_name": student.username,
            "email": student.email,
            "profile_picture": student_record.profile_picture if student_record else None
        },
        "summary": {
            "total_sessions": len(sessions),
            "assigned_sessions": len(assigned_sessions),
            "self_selected_sessions": len(self_selected_sessions),
            "total_duration_seconds": total_seconds,
            "average_accuracy": (
                sum(accuracy_values) / len(accuracy_values)
                if accuracy_values else None
            ),
            "average_pain_change": (
                sum(pain_changes) / len(pain_changes)
                if pain_changes else None
            ),
            "activity_streak": streak,
            "last_session": (
                sessions[0].completion_date.isoformat()
                if sessions and sessions[0].completion_date else None
            )
        },
        "appointments": appointments_data,
        "exercises": per_exercise,
        "weekly_activity": weekly_activity,
        "recent_sessions": recent_sessions
    }

@app.get("/physio/appointments/{physio_id}")
def get_physio_appointments(physio_id: int, db: Session = Depends(get_db)):
    appointments = db.query(
        models.Appointment, models.User.username, models.Student.matric_no
    ).join(
        models.User, models.Appointment.student_id == models.User.user_id
    ).join(
        models.Student, models.Appointment.student_id == models.Student.student_id
    ).filter(
        models.Appointment.therapist_id == physio_id
    ).order_by(models.Appointment.schedule_time).all()
    
    result = []
    for appt, username, matric_no in appointments:
        meeting_room = ensure_meeting_room(appt)
        assessment_chat = db.query(models.LiveChatSession).filter(
            models.LiveChatSession.consultation_appointment_id == appt.appointment_id
        ).order_by(models.LiveChatSession.created_at.desc()).first()
        if assessment_chat is None:
            assessment_chat = db.query(models.LiveChatSession).filter(
                models.LiveChatSession.student_id == appt.student_id,
                models.LiveChatSession.therapist_id == physio_id,
                models.LiveChatSession.created_at <= appt.schedule_time
            ).order_by(models.LiveChatSession.created_at.desc()).first()
        result.append({
            "appointment_id": appt.appointment_id,
            "student_id": appt.student_id,
            "student_name": username,
            "matric_no": matric_no,
            "schedule_time": appt.schedule_time,
            "status": appt.status,
            "evaluation": appt.evaluation,
            "prescription": appt.prescription,
            "assessment_subject": assessment_chat.subject if assessment_chat else None,
            "assessment_discipline": assessment_chat.discipline if assessment_chat else None,
            "triage_data": assessment_chat.triage_data if assessment_chat else None,
            "chat_session_id": assessment_chat.session_id if assessment_chat else None,
            "meeting_room": meeting_room
        })
    db.commit()
    return {"appointments": result}

class AssignedExercise(BaseModel):
    exercise_id: int
    assigned_sets: int
    assigned_duration: int
    assigned_reps: int | None = None
    assigned_days: int = 1
    assigned_tracking_mode: str = "duration"
    evaluation: str | None = None

class RecordSessionReq(BaseModel):
    prescription: str
    evaluation: str | None = None
    exercises: list[AssignedExercise]


class TeleconsultationReq(RecordSessionReq):
    physio_id: int

@app.post("/physio/appointments/{appointment_id}/prescribe")
def record_session(appointment_id: int, req: RecordSessionReq, db: Session = Depends(get_db)):
    appointment = db.query(models.Appointment).filter(models.Appointment.appointment_id == appointment_id).first()
    if not appointment:
        raise HTTPException(status_code=404, detail="Appointment not found")
        
    appointment.prescription = req.prescription
    if req.evaluation is not None:
        appointment.evaluation = req.evaluation
    appointment.status = "Completed"
    
    db.query(models.PrescribedExercise).filter(models.PrescribedExercise.appointment_id == appointment_id).delete()
    
    for ex in req.exercises:
        tracking_mode = ex.assigned_tracking_mode.strip().lower()
        if tracking_mode not in {"duration", "reps"}:
            raise HTTPException(status_code=422, detail="Tracking mode must be duration or reps")
        if ex.assigned_sets < 1 or ex.assigned_days < 1:
            raise HTTPException(status_code=422, detail="Sets and plan days must be at least 1")
        if tracking_mode == "duration" and ex.assigned_duration < 1:
            raise HTTPException(status_code=422, detail="Duration must be at least 1 second")
        if tracking_mode == "reps" and (ex.assigned_reps is None or ex.assigned_reps < 1):
            raise HTTPException(status_code=422, detail="Repetitions must be at least 1")
        pe = models.PrescribedExercise(
            appointment_id=appointment_id,
            exercise_id=ex.exercise_id,
            assigned_sets=ex.assigned_sets,
            assigned_duration=ex.assigned_duration,
            assigned_reps=ex.assigned_reps,
            assigned_days=ex.assigned_days,
            assigned_tracking_mode=tracking_mode,
            evaluation=ex.evaluation
        )
        db.add(pe)
        
    db.commit()
    return {"message": "Session recorded successfully"}


@app.post("/physio/chats/{session_id}/prescribe")
def record_teleconsultation(
    session_id: int,
    req: TeleconsultationReq,
    db: Session = Depends(get_db),
):
    chat = db.query(models.LiveChatSession).filter(
        models.LiveChatSession.session_id == session_id,
        models.LiveChatSession.therapist_id == req.physio_id,
    ).first()
    if not chat:
        raise HTTPException(status_code=404, detail="Assigned chat not found")

    appointment = None
    if chat.consultation_appointment_id:
        appointment = db.query(models.Appointment).filter(
            models.Appointment.appointment_id == chat.consultation_appointment_id
        ).first()
    if appointment is None:
        appointment = models.Appointment(
            student_id=chat.student_id,
            therapist_id=chat.therapist_id,
            schedule_time=datetime.utcnow(),
            status="Completed",
            meeting_room=chat.teleconference_room,
        )
        db.add(appointment)
        db.flush()
        chat.consultation_appointment_id = appointment.appointment_id

    appointment.prescription = req.prescription.strip()
    if not appointment.prescription:
        raise HTTPException(status_code=422, detail="Prescription cannot be empty")
    appointment.evaluation = req.evaluation
    appointment.status = "Completed"
    chat.consultation_prescription = appointment.prescription

    db.query(models.PrescribedExercise).filter(
        models.PrescribedExercise.appointment_id == appointment.appointment_id
    ).delete()
    for ex in req.exercises:
        tracking_mode = ex.assigned_tracking_mode.strip().lower()
        if tracking_mode not in {"duration", "reps"}:
            raise HTTPException(status_code=422, detail="Tracking mode must be duration or reps")
        if ex.assigned_sets < 1 or ex.assigned_days < 1:
            raise HTTPException(status_code=422, detail="Sets and plan days must be at least 1")
        if tracking_mode == "duration" and ex.assigned_duration < 1:
            raise HTTPException(status_code=422, detail="Duration must be at least 1 second")
        if tracking_mode == "reps" and (ex.assigned_reps is None or ex.assigned_reps < 1):
            raise HTTPException(status_code=422, detail="Repetitions must be at least 1")
        db.add(models.PrescribedExercise(
            appointment_id=appointment.appointment_id,
            exercise_id=ex.exercise_id,
            assigned_sets=ex.assigned_sets,
            assigned_duration=ex.assigned_duration,
            assigned_reps=ex.assigned_reps,
            assigned_days=ex.assigned_days,
            assigned_tracking_mode=tracking_mode,
            evaluation=ex.evaluation,
        ))

    db.add(models.ChatLog(
        session_id=session_id,
        sender_id=chat.therapist_id,
        content=f"Consultation prescription:\n{appointment.prescription}",
    ))
    db.commit()
    return {
        "message": "Teleconsultation prescription recorded successfully",
        "appointment_id": appointment.appointment_id,
    }

@app.get("/physio/rentals/{physio_id}")
def get_physio_rentals(physio_id: int, db: Session = Depends(get_db)):
    physio = db.query(models.Physiotherapist).filter(
        models.Physiotherapist.therapist_id == physio_id
    ).first()
    if not physio:
        raise HTTPException(status_code=403, detail="Physiotherapist access required")

    patient_ids = {
        student_id for (student_id,) in db.query(models.Appointment.student_id).filter(
            models.Appointment.therapist_id == physio_id
        ).distinct().all()
    }
    if not patient_ids:
        return {"rentals": []}

    rentals = db.query(
        models.RentalRecord,
        models.User.username,
        models.Student.matric_no,
        models.Equipment.name,
        models.RentalReason.description
    ).join(
        models.User, models.RentalRecord.student_id == models.User.user_id
    ).join(
        models.Student, models.RentalRecord.student_id == models.Student.student_id
    ).join(
        models.Equipment, models.RentalRecord.equipment_id == models.Equipment.equipment_id
    ).outerjoin(
        models.RentalReason, models.RentalRecord.rental_reason_id == models.RentalReason.rental_reason_id
    ).filter(
        models.RentalRecord.student_id.in_(patient_ids)
    ).order_by(models.RentalRecord.collection_date.desc()).all()
    
    result = []
    for r, username, matric_no, eq_name, reason_desc in rentals:
        final_reason = reason_desc if reason_desc else "No reason provided"
        if r.custom_reason:
            final_reason = f"{final_reason}: {r.custom_reason}"
            
        result.append({
            "rental_record_id": r.rental_record_id,
            "student_id": r.student_id,
            "student_name": username,
            "matric_no": matric_no,
            "equipment_name": eq_name,
            "collection_date": r.collection_date,
            "collection_method": r.collection_method,
            "proof_of_collection": r.proof_of_collection,
            "status": r.status,
            "return_status": r.return_status,
            "reason": final_reason
        })
    return {"rentals": result}


@app.post("/physio/rentals/{rental_id}/approve")
def approve_rental(rental_id: int, physio_id: int, db: Session = Depends(get_db)):
    physio = db.query(models.Physiotherapist).filter(
        models.Physiotherapist.therapist_id == physio_id
    ).first()
    if not physio:
        raise HTTPException(status_code=403, detail="Physiotherapist access required")
    rental = db.query(models.RentalRecord).filter(models.RentalRecord.rental_record_id == rental_id).first()
    if not rental:
        raise HTTPException(status_code=404, detail="Rental not found")
    if rental.status != "Pending":
        raise HTTPException(status_code=400, detail="Only pending rentals can be approved")
    relationship = db.query(models.Appointment).filter(
        models.Appointment.therapist_id == physio_id,
        models.Appointment.student_id == rental.student_id
    ).first()
    if not relationship:
        raise HTTPException(status_code=403, detail="This patient is not assigned to you")
    
    # Check equipment stock
    equipment = db.query(models.Equipment).filter(models.Equipment.equipment_id == rental.equipment_id).first()
    if not equipment or equipment.stock < 1:
        raise HTTPException(status_code=400, detail="Equipment out of stock")
    
    rental.status = "Approved"
    db.commit()
    return {"status": "success", "message": "Rental approved"}

@app.post("/physio/rentals/{rental_id}/reject")
def reject_rental(rental_id: int, physio_id: int, db: Session = Depends(get_db)):
    physio = db.query(models.Physiotherapist).filter(
        models.Physiotherapist.therapist_id == physio_id
    ).first()
    if not physio:
        raise HTTPException(status_code=403, detail="Physiotherapist access required")
    rental = db.query(models.RentalRecord).filter(models.RentalRecord.rental_record_id == rental_id).first()
    if not rental:
        raise HTTPException(status_code=404, detail="Rental not found")
    if rental.status != "Pending":
        raise HTTPException(status_code=400, detail="Only pending rentals can be rejected")
    relationship = db.query(models.Appointment).filter(
        models.Appointment.therapist_id == physio_id,
        models.Appointment.student_id == rental.student_id
    ).first()
    if not relationship:
        raise HTTPException(status_code=403, detail="This patient is not assigned to you")
    
    rental.status = "Rejected"
    db.commit()
    return {"status": "success", "message": "Rental rejected"}


@app.get("/appointments/available_physios/{student_id}")
def get_available_physios(student_id: int, db: Session = Depends(get_db)):
    # 1. Try to find the assigned physiotherapist via active prescription
    presc = db.query(models.Appointment).filter(
        models.Appointment.student_id == student_id,
        models.Appointment.prescription != None
    ).order_by(models.Appointment.schedule_time.desc()).first()
    
    if presc:
        physio = db.query(models.User, models.Physiotherapist).join(
            models.Physiotherapist, models.User.user_id == models.Physiotherapist.therapist_id
        ).filter(models.User.user_id == presc.therapist_id).first()
        if physio:
            u, p = physio
            return {"physios": [{"therapist_id": u.user_id, "name": u.username, "specialization": p.specialization, "recommended": True, "leave_start_date": p.leave_start_date.isoformat() if p.leave_start_date else None, "leave_end_date": p.leave_end_date.isoformat() if p.leave_end_date else None}]}
            
    # 2. Try to find via recent Live Chat session
    session = db.query(models.LiveChatSession).filter(
        models.LiveChatSession.student_id == student_id,
        models.LiveChatSession.therapist_id.isnot(None)
    ).order_by(models.LiveChatSession.created_at.desc()).first()
    
    if session:
        physio = db.query(models.User, models.Physiotherapist).join(
            models.Physiotherapist, models.User.user_id == models.Physiotherapist.therapist_id
        ).filter(models.User.user_id == session.therapist_id).first()
        if physio:
            u, p = physio
            return {"physios": [{"therapist_id": u.user_id, "name": u.username, "specialization": p.specialization, "recommended": True, "leave_start_date": p.leave_start_date.isoformat() if p.leave_start_date else None, "leave_end_date": p.leave_end_date.isoformat() if p.leave_end_date else None}]}
            
    # 3. Fallback: Return all physios
    all_physios = db.query(models.User, models.Physiotherapist).join(
        models.Physiotherapist, models.User.user_id == models.Physiotherapist.therapist_id
    ).all()
    
    result = []
    for u, p in all_physios:
        result.append({"therapist_id": u.user_id, "name": u.username, "specialization": p.specialization, "recommended": False, "leave_start_date": p.leave_start_date.isoformat() if p.leave_start_date else None, "leave_end_date": p.leave_end_date.isoformat() if p.leave_end_date else None})
    return {"physios": result}

@app.get("/appointments/student/{student_id}")
def get_student_appointments(student_id: int, db: Session = Depends(get_db)):
    appointments = db.query(
        models.Appointment, models.User.username, models.Physiotherapist.specialization
    ).join(
        models.User, models.Appointment.therapist_id == models.User.user_id
    ).join(
        models.Physiotherapist, models.Appointment.therapist_id == models.Physiotherapist.therapist_id
    ).filter(
        models.Appointment.student_id == student_id
    ).order_by(models.Appointment.schedule_time.desc()).all()
    
    result = []
    for appt, physio_name, spec in appointments:
        meeting_room = ensure_meeting_room(appt)
        reason_desc = None
        if appt.reason_id:
            reason = db.query(models.CancellationReason).filter(models.CancellationReason.reason_id == appt.reason_id).first()
            if reason:
                reason_desc = reason.description
                
        result.append({
            "appointment_id": appt.appointment_id,
            "physiotherapist_name": physio_name,
            "specialization": spec,
            "schedule_time": appt.schedule_time,
            "status": appt.status,
            "evaluation": appt.evaluation,
            "cancellation_reason": reason_desc,
            "meeting_room": meeting_room
        })
    db.commit()
    return {"appointments": result}

@app.get("/appointments/cancellation_reasons")
def get_cancellation_reasons(db: Session = Depends(get_db)):
    reasons = db.query(models.CancellationReason).all()
    return {"reasons": [{"reason_id": r.reason_id, "description": r.description} for r in reasons]}


class BookAppointmentReq(BaseModel):
    student_id: int
    therapist_id: int
    schedule_time: str

class CancelAppointmentReq(BaseModel):
    reason_id: int
    other_reason: str | None = None

class ApplyLeaveReq(BaseModel):
    start_date: str
    end_date: str
    cover_colleague_id: int

class TransferAppointmentReq(BaseModel):
    new_therapist_id: int

class RentalRequest(BaseModel):
    student_id: int
    equipment_id: int
    rental_reason_id: int
    custom_reason: Optional[str] = None
    rental_duration: int
    collection_method: str
    proof_of_collection: Optional[str] = None
    collection_date: str

@app.post("/appointments/book")
def book_appointment(req: BookAppointmentReq, db: Session = Depends(get_db)):
    appt = models.Appointment(
        student_id=req.student_id,
        therapist_id=req.therapist_id,
        schedule_time=datetime.fromisoformat(req.schedule_time),
        status="Scheduled",
        meeting_room=f"rehab-ai-{secrets.token_hex(16)}"
    )
    db.add(appt)
    db.commit()
    db.refresh(appt)
    return {"status": "success", "appointment_id": appt.appointment_id}

@app.put("/appointments/{appointment_id}/cancel")
def cancel_appointment(appointment_id: int, req: CancelAppointmentReq, db: Session = Depends(get_db)):
    appt = db.query(models.Appointment).filter(models.Appointment.appointment_id == appointment_id).first()
    if not appt:
        raise HTTPException(status_code=404, detail="Appointment not found")
        
    appt.status = "Cancelled"
    appt.reason_id = req.reason_id
    
    # If other reason is provided, we might want to store it in evaluation or a separate field.
    # We will just append it to evaluation for now since there's no other_reason field in Appointment.
    if req.other_reason:
        appt.evaluation = f"Cancellation Note: {req.other_reason}"
        
    db.commit()
    return {"status": "success"}


@app.get("/physiotherapists/colleagues/{therapist_id}")
def get_physio_colleagues(therapist_id: int, db: Session = Depends(get_db)):
    # Find the current physiotherapist's specialization
    current_physio = db.query(models.Physiotherapist).filter(models.Physiotherapist.therapist_id == therapist_id).first()
    if not current_physio:
        raise HTTPException(status_code=404, detail="Physiotherapist not found")
        
    spec = current_physio.specialization
    
    # Find all other physiotherapists with the same specialization
    colleagues = db.query(models.User, models.Physiotherapist).join(
        models.Physiotherapist, models.User.user_id == models.Physiotherapist.therapist_id
    ).filter(
        models.Physiotherapist.specialization == spec,
        models.Physiotherapist.therapist_id != therapist_id
    ).all()
    
    result = []
    for u, p in colleagues:
        result.append({
            "therapist_id": u.user_id,
            "name": u.username,
            "specialization": p.specialization
        })
    return {"colleagues": result}

@app.put("/appointments/{appointment_id}/transfer")
def transfer_appointment(appointment_id: int, req: TransferAppointmentReq, db: Session = Depends(get_db)):
    appt = db.query(models.Appointment).filter(models.Appointment.appointment_id == appointment_id).first()
    if not appt:
        raise HTTPException(status_code=404, detail="Appointment not found")
        
    # verify new therapist exists
    new_therapist = db.query(models.Physiotherapist).filter(models.Physiotherapist.therapist_id == req.new_therapist_id).first()
    if not new_therapist:
        raise HTTPException(status_code=404, detail="New Physiotherapist not found")
        
    appt.therapist_id = req.new_therapist_id
    db.commit()
    return {"status": "success"}

@app.put("/physio/leave/{physio_id}")
def apply_leave(physio_id: int, req: ApplyLeaveReq, db: Session = Depends(get_db)):
    from datetime import datetime
    physio = db.query(models.Physiotherapist).filter(models.Physiotherapist.therapist_id == physio_id).first()
    if not physio:
        raise HTTPException(status_code=404, detail="Physiotherapist not found")
        
    start_dt = datetime.fromisoformat(req.start_date.replace('Z', '+00:00'))
    end_dt = datetime.fromisoformat(req.end_date.replace('Z', '+00:00'))
    
    physio.leave_start_date = start_dt
    physio.leave_end_date = end_dt
    
    appointments = db.query(models.Appointment).filter(
        models.Appointment.therapist_id == physio_id,
        models.Appointment.status == "Scheduled",
        models.Appointment.schedule_time >= start_dt,
        models.Appointment.schedule_time <= end_dt
    ).all()
    
    for appt in appointments:
        appt.therapist_id = req.cover_colleague_id
        
    db.commit()
    return {"status": "success", "transferred_count": len(appointments)}

@app.post("/rentals/request")
def request_rental(req: RentalRequest, db: Session = Depends(get_db)):
    new_rental = models.RentalRecord(
        student_id=req.student_id,
        equipment_id=req.equipment_id,
        rental_reason_id=req.rental_reason_id,
        custom_reason=req.custom_reason,
        rental_duration=req.rental_duration,
        collection_method=req.collection_method,
        proof_of_collection=req.proof_of_collection,
        collection_date=datetime.fromisoformat(req.collection_date),
        status="Pending"
    )
    db.add(new_rental)
    db.commit()
    db.refresh(new_rental)
    return {"status": "success", "rental_record_id": new_rental.rental_record_id}

@app.get("/rentals/student/{student_id}")
def get_student_rentals(student_id: int, db: Session = Depends(get_db)):
    rentals = db.query(
        models.RentalRecord,
        models.Equipment.name,
        models.Equipment.image,
        models.RentalReason.description
    ).join(
        models.Equipment, models.RentalRecord.equipment_id == models.Equipment.equipment_id
    ).join(
        models.RentalReason, models.RentalRecord.rental_reason_id == models.RentalReason.rental_reason_id
    ).filter(
        models.RentalRecord.student_id == student_id
    ).order_by(models.RentalRecord.collection_date.desc()).all()
    
    result = []
    for r, eq_name, eq_image, reason_desc in rentals:
        result.append({
            "rental_record_id": r.rental_record_id,
            "equipment_name": eq_name,
            "equipment_image": eq_image,
            "reason_description": reason_desc,
            "custom_reason": r.custom_reason,
            "collection_date": r.collection_date,
            "return_date": r.return_date,
            "status": r.status,
            "return_status": r.return_status,
            "proof_of_status": r.proof_of_status
        })
    return {"rentals": result}

class SessionLogRequest(BaseModel):
    student_id: int
    exercise_id: int
    completed_reps: Optional[int] = None
    duration_seconds: Optional[int] = None
    pain_before: Optional[int] = None
    pain_after: Optional[int] = None
    accuracy_score: Optional[float] = None
    completed_sets: Optional[int] = None
    planned_sets: Optional[int] = None
    schedule_id: Optional[int] = None
    session_origin: Optional[str] = None

@app.post("/session_logs")
def log_session(req: SessionLogRequest, db: Session = Depends(get_db)):
    if req.session_origin not in {None, "Assigned", "Self-selected"}:
        raise HTTPException(status_code=400, detail="Invalid session origin")

    if req.schedule_id:
        existing_log = db.query(models.SessionLog).filter(models.SessionLog.schedule_id == req.schedule_id).first()
        if existing_log:
            existing_log.completed_reps = req.completed_reps
            existing_log.duration_seconds = req.duration_seconds
            existing_log.pain_before = req.pain_before
            existing_log.pain_after = req.pain_after
            existing_log.accuracy_score = req.accuracy_score
            existing_log.completed_sets = req.completed_sets
            existing_log.planned_sets = req.planned_sets
            if req.session_origin is not None:
                existing_log.session_origin = req.session_origin
            existing_log.completion_date = datetime.utcnow()
            existing_log.status = "Completed"
            db.commit()
            return {"status": "success", "session_id": existing_log.schedule_id}
            
    new_log = models.SessionLog(
        student_id=req.student_id,
        exercise_id=req.exercise_id,
        completed_reps=req.completed_reps,
        duration_seconds=req.duration_seconds,
        pain_before=req.pain_before,
        pain_after=req.pain_after,
        accuracy_score=req.accuracy_score,
        completed_sets=req.completed_sets,
        planned_sets=req.planned_sets,
        session_origin=req.session_origin or "Self-selected",
        completion_date=datetime.utcnow(),
        status="Completed"
    )
    db.add(new_log)
    db.commit()
    db.refresh(new_log)
    return {"status": "success", "session_id": new_log.schedule_id}


@app.get("/students/{student_id}/progress")
def get_student_progress(
    student_id: int,
    db: Session = Depends(get_db)
):
    student = db.query(models.User).filter(models.User.user_id == student_id).first()
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")

    # Fetch all appointments for this student
    appointments = db.query(models.Appointment).filter(
        models.Appointment.student_id == student_id
    ).order_by(models.Appointment.schedule_time.desc()).all()

    appointments_data = []
    exercise_assignments = {} # For all exercises
    
    sessions = db.query(models.SessionLog).filter(
        models.SessionLog.student_id == student_id,
        models.SessionLog.status == "Completed"
    ).order_by(models.SessionLog.completion_date.desc()).all()

    session_exercise_ids = {session.exercise_id for session in sessions}
    exercise_catalog = {
        exercise.exercise_id: exercise.name
        for exercise in db.query(models.Exercise).filter(
            models.Exercise.exercise_id.in_(session_exercise_ids)
        ).all()
    } if session_exercise_ids else {}
    
    from datetime import datetime, timedelta

    for i, appt in enumerate(appointments):
        prescribed_rows = db.query(models.PrescribedExercise, models.Exercise).join(
            models.Exercise, models.PrescribedExercise.exercise_id == models.Exercise.exercise_id
        ).filter(models.PrescribedExercise.appointment_id == appt.appointment_id).all()
        
        appt_exercises = []
        appt_assigned_exercise_ids = set()
        for prescribed, exercise in prescribed_rows:
            ex_data = {
                "exercise_id": exercise.exercise_id,
                "name": exercise.name,
                "assigned_sets": prescribed.assigned_sets,
                "assigned_duration": prescribed.assigned_duration,
                "assigned_reps": prescribed.assigned_reps,
                "assigned_days": prescribed.assigned_days,
                "assigned_tracking_mode": prescribed.assigned_tracking_mode,
                "evaluation": prescribed.evaluation
            }
            appt_exercises.append(ex_data)
            appt_assigned_exercise_ids.add(exercise.exercise_id)
            exercise_assignments[exercise.exercise_id] = ex_data
            
        chat_session = db.query(models.LiveChatSession).filter(
            models.LiveChatSession.consultation_appointment_id == appt.appointment_id
        ).first()
        triage_data = chat_session.triage_data if chat_session else None

        # Determine time window for this appointment
        start_time = appt.schedule_time
        end_time = appointments[i-1].schedule_time if i > 0 else None

        appt_sessions = []
        for s in sessions:
            if not s.completion_date: continue
            if start_time and s.completion_date < start_time: continue
            if end_time and s.completion_date >= end_time: continue
            if s.exercise_id in appt_assigned_exercise_ids:
                appt_sessions.append(s)

        total_seconds = sum(s.duration_seconds or 0 for s in appt_sessions)
        accuracy_values = [s.accuracy_score for s in appt_sessions if s.accuracy_score is not None]
        pain_changes = [s.pain_before - s.pain_after for s in appt_sessions if s.pain_before is not None and s.pain_after is not None]
        
        session_days = sorted({s.completion_date.date() for s in appt_sessions}, reverse=True)
        streak = 0
        if session_days:
            streak = 1
            expected = session_days[0]
            for day in session_days[1:]:
                expected = expected - timedelta(days=1)
                if day == expected:
                    streak += 1
                elif day < expected:
                    break

        appt_summary = {
            "total_sessions": len(appt_sessions),
            "total_duration_minutes": total_seconds // 60,
            "average_accuracy": sum(accuracy_values) / len(accuracy_values) if accuracy_values else None,
            "average_pain_change": sum(pain_changes) / len(pain_changes) if pain_changes else None,
            "activity_streak": streak
        }

        reference_date = end_time.date() if end_time else datetime.utcnow().date()
        appt_weekly = []
        for days_ago in range(6, -1, -1):
            day = reference_date - timedelta(days=days_ago)
            day_sessions = [s for s in appt_sessions if s.completion_date.date() == day]
            appt_weekly.append({
                "date": day.isoformat(),
                "session_count": len(day_sessions),
                "duration_seconds": sum(s.duration_seconds or 0 for s in day_sessions)
            })
            
        appt_recent = []
        for s in appt_sessions[:20]:
            ex_info = next((e for e in appt_exercises if e['exercise_id'] == s.exercise_id), {})
            appt_recent.append({
                "session_id": s.schedule_id,
                "exercise_id": s.exercise_id,
                "exercise_name": ex_info.get("name", exercise_catalog.get(s.exercise_id, "Exercise")),
                "source": "Assigned",
                "completion_date": s.completion_date.isoformat(),
                "completed_reps": s.completed_reps,
                "duration_seconds": s.duration_seconds,
                "completed_sets": s.completed_sets,
                "accuracy_score": s.accuracy_score,
                "pain_before": s.pain_before,
                "pain_after": s.pain_after
            })

        appointments_data.append({
            "appointment_id": appt.appointment_id,
            "date": appt.schedule_time.isoformat() if appt.schedule_time else None,
            "status": appt.status,
            "prescription": appt.prescription,
            "assigned_exercises": appt_exercises,
            "triage_data": triage_data,
            "summary": appt_summary,
            "weekly_activity": appt_weekly,
            "recent_sessions": appt_recent
        })

    exercise_ids = set(exercise_assignments.keys())

    def session_origin(session):
        if session.session_origin in {"Assigned", "Self-selected"}:
            return session.session_origin
        assignment = exercise_assignments.get(session.exercise_id)
        if assignment is None:
            return "Self-selected"
        if (
            session.planned_sets is not None
            and assignment["assigned_sets"] is not None
            and session.planned_sets != assignment["assigned_sets"]
        ):
            return "Self-selected"
        return "Assigned"

    assigned_sessions = [
        session for session in sessions if session_origin(session) == "Assigned"
    ]
    self_selected_sessions = [
        session for session in sessions if session_origin(session) == "Self-selected"
    ]

    total_seconds = sum(session.duration_seconds or 0 for session in sessions)
    accuracy_values = [
        session.accuracy_score for session in sessions
        if session.accuracy_score is not None
    ]
    pain_changes = [
        session.pain_before - session.pain_after for session in sessions
        if session.pain_before is not None and session.pain_after is not None
    ]

    session_days = sorted({
        session.completion_date.date() for session in sessions
        if session.completion_date is not None
    }, reverse=True)
    streak = 0
    if session_days:
        streak = 1
        expected = session_days[0]
        from datetime import timedelta
        for day in session_days[1:]:
            expected = expected - timedelta(days=1)
            if day == expected:
                streak += 1
            elif day < expected:
                break

    per_exercise = []
    for exercise_id, assignment in exercise_assignments.items():
        exercise_sessions = [
            session for session in assigned_sessions
            if session.exercise_id == exercise_id
        ]
        exercise_accuracy = [
            session.accuracy_score for session in exercise_sessions
            if session.accuracy_score is not None
        ]
        latest = exercise_sessions[0] if exercise_sessions else None
        per_exercise.append({
            **assignment,
            "source": "Assigned",
            "session_count": len(exercise_sessions),
            "total_duration_seconds": sum(
                session.duration_seconds or 0 for session in exercise_sessions
            ),
            "average_accuracy": (
                sum(exercise_accuracy) / len(exercise_accuracy)
                if exercise_accuracy else None
            ),
            "last_completed": (
                latest.completion_date.isoformat()
                if latest and latest.completion_date else None
            )
        })

    for exercise_id in sorted({
        session.exercise_id for session in self_selected_sessions
    }):
        exercise_sessions = [
            session for session in self_selected_sessions
            if session.exercise_id == exercise_id
        ]
        exercise_accuracy = [
            session.accuracy_score for session in exercise_sessions
            if session.accuracy_score is not None
        ]
        latest = exercise_sessions[0]
        per_exercise.append({
            "exercise_id": exercise_id,
            "name": exercise_catalog.get(exercise_id, "Exercise"),
            "source": "Self-selected",
            "assigned_sets": None,
            "assigned_duration": None,
            "evaluation": None,
            "session_count": len(exercise_sessions),
            "total_duration_seconds": sum(
                session.duration_seconds or 0 for session in exercise_sessions
            ),
            "average_accuracy": (
                sum(exercise_accuracy) / len(exercise_accuracy)
                if exercise_accuracy else None
            ),
            "last_completed": (
                latest.completion_date.isoformat()
                if latest.completion_date else None
            )
        })

    today = datetime.utcnow().date()
    weekly_activity = []
    for days_ago in range(6, -1, -1):
        day = today - timedelta(days=days_ago)
        day_sessions = [
            session for session in sessions
            if session.completion_date and session.completion_date.date() == day
        ]
        weekly_activity.append({
            "date": day.isoformat(),
            "session_count": len(day_sessions),
            "duration_seconds": sum(
                session.duration_seconds or 0 for session in day_sessions
            )
        })

    recent_sessions = []
    for session in sessions[:20]:
        exercise = exercise_assignments.get(session.exercise_id, {})
        recent_sessions.append({
            "session_id": session.schedule_id,
            "exercise_id": session.exercise_id,
            "exercise_name": exercise.get(
                "name", exercise_catalog.get(session.exercise_id, "Exercise")
            ),
            "source": session_origin(session),
            "completion_date": (
                session.completion_date.isoformat()
                if session.completion_date else None
            ),
            "completed_reps": session.completed_reps,
            "duration_seconds": session.duration_seconds,
            "completed_sets": session.completed_sets,
            "accuracy_score": session.accuracy_score,
            "pain_before": session.pain_before,
            "pain_after": session.pain_after
        })

    student_record = db.query(models.Student).filter(models.Student.student_id == student.user_id).first()

    return {
        "patient": {
            "student_id": student.user_id,
            "student_name": student.username,
            "profile_picture": student_record.profile_picture if student_record else None,
        },
        "appointments": appointments_data,
        "summary": {
            "total_sessions": len(sessions),
            "total_duration_minutes": total_seconds // 60,
            "average_accuracy": sum(accuracy_values) / len(accuracy_values) if accuracy_values else None,
            "average_pain_change": sum(pain_changes) / len(pain_changes) if pain_changes else None,
            "activity_streak": streak
        },
        "exercises": per_exercise,
        "recent_sessions": recent_sessions,
        "weekly_activity": weekly_activity
    }
