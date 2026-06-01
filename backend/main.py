from fastapi import FastAPI, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel
from backend.database import engine, get_db
from backend import models
from fastapi.responses import StreamingResponse
import cv2
from backend.ai.pose_detector import PoseDetector
from backend.ai.angle_calculator import calculate_angle

models.Base.metadata.create_all(bind=engine)

app = FastAPI(title="Rehab AI Backend")

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
    return {"equipment": equipment}

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
