import sys

with open('backend/main.py', 'r', encoding='utf-8') as f:
    content = f.read()

# Models to add
models_code = """
class BookAppointmentReq(BaseModel):
    student_id: int
    therapist_id: int
    schedule_time: datetime

class CancelAppointmentReq(BaseModel):
    reason_id: int
    other_reason: Optional[str] = None
"""

# Endpoints to add
endpoints_code = """
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
            return {"physios": [{"therapist_id": u.user_id, "name": u.username, "specialization": p.specialization, "recommended": True}]}
            
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
            return {"physios": [{"therapist_id": u.user_id, "name": u.username, "specialization": p.specialization, "recommended": True}]}
            
    # 3. Fallback: Return all physios
    all_physios = db.query(models.User, models.Physiotherapist).join(
        models.Physiotherapist, models.User.user_id == models.Physiotherapist.therapist_id
    ).all()
    
    result = []
    for u, p in all_physios:
        result.append({"therapist_id": u.user_id, "name": u.username, "specialization": p.specialization, "recommended": False})
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
"""

# Insert models right before the first endpoint
if "class SendMessageReq(BaseModel):" in content:
    idx = content.find("@app.post(\"/chat/send\")")
    new_content = content[:idx] + models_code + "\n" + content[idx:]
else:
    print("Could not find insertion point for models")
    sys.exit(1)

# Append endpoints
new_content += "\n" + endpoints_code + "\n"

with open('backend/main.py', 'w', encoding='utf-8') as f:
    f.write(new_content)

print("Added appointment routes to main.py")
