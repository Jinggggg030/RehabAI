from typing import Optional, List
from fastapi import FastAPI, Depends, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session
from pydantic import BaseModel
from backend.database import engine, get_db
from backend import models
from fastapi.responses import StreamingResponse
from sqlalchemy.orm.attributes import flag_modified
import cv2
from backend.ai.pose_detector import PoseDetector
from backend.ai.angle_calculator import calculate_angle
from backend.ai.chatbot import chatbot_instance

models.Base.metadata.create_all(bind=engine)

app = FastAPI(title="Rehab AI Backend")

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
    matric_no: str | None = None

@app.post("/users/profile")
def create_user_profile(profile: UserProfileCreate, db: Session = Depends(get_db)):
    existing_user = db.query(models.User).filter(models.User.supabase_id == profile.supabase_id).first()
    if existing_user:
        raise HTTPException(status_code=400, detail="User profile already exists")
    
    new_user = models.User(
        supabase_id=profile.supabase_id,
        username=profile.username,
        identity_number=profile.identity_number,
        email=profile.email,
        gender=profile.gender,
        contact_number=profile.contact_number,
        address=profile.address,
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
    
    return {"message": "Profile created successfully", "user_id": new_user.user_id}

@app.get("/users/profile/{supabase_id}")
def check_user_profile(supabase_id: str, db: Session = Depends(get_db)):
    user = db.query(models.User).filter(models.User.supabase_id == supabase_id).first()
    if user:
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
            "matric_no": student.matric_no if student else None
        }
    return {"exists": False}

@app.get("/users")
def get_all_users(db: Session = Depends(get_db)):
    users = db.query(models.User).all()
    return {"users": users}

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

@app.get("/rental_records")
def get_all_rental_records(db: Session = Depends(get_db)):
    records = db.query(models.RentalRecord).all()
    return {"rental_records": records}

@app.get("/cancellation_reasons")
def get_all_cancellation_reasons(db: Session = Depends(get_db)):
    reasons = db.query(models.CancellationReason).all()
    return {"cancellation_reasons": reasons}

@app.get("/appointments")
def get_all_appointments(db: Session = Depends(get_db)):
    appointments = db.query(models.Appointment).all()
    return {"appointments": appointments}

@app.get("/prescriptions")
def get_all_prescriptions(db: Session = Depends(get_db)):
    prescriptions = db.query(models.Prescription).all()
    return {"prescriptions": prescriptions}

@app.get("/exercises")
def get_all_exercises(db: Session = Depends(get_db)):
    exercises = db.query(models.Exercise).all()
    return {"exercises": exercises}

@app.get("/prescribed_exercises")
def get_all_prescribed_exercises(db: Session = Depends(get_db)):
    prescribed = db.query(models.Prescribed_Exercise).all()
    return {"prescribed_exercises": prescribed}

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
        .join(models.Prescription, models.PrescribedExercise.prescription_id == models.Prescription.prescription_id)\
        .filter(models.Prescription.student_id == student_id)\
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
        result.append({
            "session_id": chat.session_id,
            "subject": chat.subject,
            "discipline": chat.discipline,
            "session_status": chat.session_status,
            "triage_data": chat.triage_data,
            "created_at": chat.created_at,
            "student_name": chat.student_name
        })
    return {"chats": result}

@app.get("/physio/patients/{physio_id}")
def get_physio_patients(physio_id: int, db: Session = Depends(get_db)):
    students = db.query(models.User.user_id, models.User.username, models.User.email).join(
        models.Prescription, models.User.user_id == models.Prescription.student_id
    ).filter(models.Prescription.therapist_id == physio_id).distinct().all()
    
    result = []
    for s in students:
        presc = db.query(models.Prescription).filter(
            models.Prescription.student_id == s.user_id,
            models.Prescription.therapist_id == physio_id,
            models.Prescription.status == 'Active'
        ).first()
        
        exercises = []
        if presc:
            pexs = db.query(models.PrescribedExercise, models.Exercise.name).join(
                models.Exercise, models.PrescribedExercise.exercise_id == models.Exercise.exercise_id
            ).filter(models.PrescribedExercise.prescription_id == presc.prescription_id).all()
            for px, ename in pexs:
                exercises.append({
                    "id": px.prescribed_exercise_id,
                    "name": ename,
                    "assigned_sets": px.assigned_sets,
                    "evaluation": px.evaluation
                })
                
        result.append({
            "student_id": s.user_id,
            "student_name": s.username,
            "email": s.email,
            "active_prescription": presc.diagnosis if presc else None,
            "exercises": exercises
        })
    return {"patients": result}

@app.get("/physio/appointments/{physio_id}")
def get_physio_appointments(physio_id: int, db: Session = Depends(get_db)):
    appointments = db.query(
        models.Appointment, models.User.username
    ).join(
        models.User, models.Appointment.student_id == models.User.user_id
    ).filter(
        models.Appointment.therapist_id == physio_id
    ).order_by(models.Appointment.schedule_time).all()
    
    result = []
    for appt, username in appointments:
        result.append({
            "appointment_id": appt.appointment_id,
            "student_name": username,
            "schedule_time": appt.schedule_time,
            "status": appt.status,
            "evaluation": appt.evaluation
        })
    return {"appointments": result}

@app.get("/physio/rentals/{physio_id}")
def get_physio_rentals(physio_id: int, db: Session = Depends(get_db)):
    rentals = db.query(
        models.RentalRecord, models.User.username, models.Equipment.name
    ).join(
        models.User, models.RentalRecord.student_id == models.User.user_id
    ).join(
        models.Equipment, models.RentalRecord.equipment_id == models.Equipment.equipment_id
    ).order_by(models.RentalRecord.collection_date.desc()).all()
    
    result = []
    for r, username, eq_name in rentals:
        result.append({
            "rental_record_id": r.rental_record_id,
            "student_name": username,
            "equipment_name": eq_name,
            "collection_date": r.collection_date,
            "status": r.status,
            "return_status": r.return_status
        })
    return {"rentals": result}


@app.post("/physio/rentals/{rental_id}/approve")
def approve_rental(rental_id: int, db: Session = Depends(get_db)):
    rental = db.query(models.RentalRecord).filter(models.RentalRecord.rental_record_id == rental_id).first()
    if not rental:
        raise HTTPException(status_code=404, detail="Rental not found")
    if rental.status != "Pending":
        raise HTTPException(status_code=400, detail="Only pending rentals can be approved")
    
    # Check equipment stock
    equipment = db.query(models.Equipment).filter(models.Equipment.equipment_id == rental.equipment_id).first()
    if not equipment or equipment.stock < 1:
        raise HTTPException(status_code=400, detail="Equipment out of stock")
    
    rental.status = "Approved"
    equipment.stock -= 1
    db.commit()
    return {"status": "success", "message": "Rental approved"}


@app.post("/physio/rentals/{rental_id}/reject")
def reject_rental(rental_id: int, db: Session = Depends(get_db)):
    rental = db.query(models.RentalRecord).filter(models.RentalRecord.rental_record_id == rental_id).first()
    if not rental:
        raise HTTPException(status_code=404, detail="Rental not found")
    if rental.status != "Pending":
        raise HTTPException(status_code=400, detail="Only pending rentals can be rejected")
    
    rental.status = "Rejected"
    db.commit()
    return {"status": "success", "message": "Rental rejected"}


@app.get("/appointments/available_physios/{student_id}")
def get_available_physios(student_id: int, db: Session = Depends(get_db)):
    # 1. Try to find the assigned physiotherapist via active prescription
    presc = db.query(models.Prescription).filter(
        models.Prescription.student_id == student_id,
        models.Prescription.status == 'Active'
    ).first()
    
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
            "cancellation_reason": reason_desc
        })
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

@app.post("/appointments/book")
def book_appointment(req: BookAppointmentReq, db: Session = Depends(get_db)):
    appt = models.Appointment(
        student_id=req.student_id,
        therapist_id=req.therapist_id,
        schedule_time=req.schedule_time,
        status="Scheduled"
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
    from datetime import datetime
    new_rental = models.RentalRecord(
        student_id=req.student_id,
        equipment_id=req.equipment_id,
        rental_reason_id=req.rental_reason_id,
        custom_reason=req.custom_reason,
        rental_duration=req.rental_duration,
        collection_date=datetime.utcnow(),
        status="Pending"
    )
    db.add(new_rental)
    db.commit()
    db.refresh(new_rental)
    return {"status": "success", "rental_record_id": new_rental.rental_record_id}

@app.get("/rentals/student/{student_id}")
def get_student_rentals(student_id: int, db: Session = Depends(get_db)):
    rentals = db.query(
        models.RentalRecord, models.Equipment.name, models.RentalReason.description
    ).join(
        models.Equipment, models.RentalRecord.equipment_id == models.Equipment.equipment_id
    ).join(
        models.RentalReason, models.RentalRecord.rental_reason_id == models.RentalReason.rental_reason_id
    ).filter(
        models.RentalRecord.student_id == student_id
    ).order_by(models.RentalRecord.collection_date.desc()).all()
    
    result = []
    for r, eq_name, reason_desc in rentals:
        result.append({
            "rental_record_id": r.rental_record_id,
            "equipment_name": eq_name,
            "reason_description": reason_desc,
            "custom_reason": r.custom_reason,
            "collection_date": r.collection_date,
            "return_date": r.return_date,
            "status": r.status,
            "return_status": r.return_status
        })
    return {"rentals": result}
