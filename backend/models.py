from sqlalchemy import Column, Integer, String, DateTime, Text, Float, ForeignKey, CheckConstraint
from sqlalchemy.orm import declarative_base
from datetime import datetime

Base = declarative_base()

class User(Base):
    __tablename__ = "User"

    user_id = Column(Integer, primary_key=True)
    username = Column(String(50), nullable=False)
    password = Column(String(12), nullable=False)
    identity_number = Column(String(12), nullable=False)
    email = Column(String(50), nullable=False)
    gender = Column(String(1), nullable=True) 
    contact_number = Column(String(11), nullable=False)
    address = Column(Text, nullable=True)
    role = Column(String(1), nullable=False)

    __table_args__ = (
        CheckConstraint("role IN ('S', 'P',)", name="check_valid_role"), 
    )

class Student(Base):
    __tablename__ = "Student"

    student_id = Column(Integer, ForeignKey("User.user_id"), primary_key=True)
    matric_no = Column(String(20), nullable=False)

class Physiotherapist(Base):
    __tablename__ = "Physiotherapist"

    therapist_id = Column(Integer, ForeignKey("User.user_id"), primary_key=True)
    specialization = Column(String(100), nullable=True)

class Category(Base):
    __tablename__ = "Category"

    category_id = Column(Integer, primary_key=True)
    description = Column(String(100), nullable=False)

class Equipment(Base):
    __tablename__ = "Equipment"

    equipment_id = Column(Integer, primary_key=True)
    category_id = Column(Integer, ForeignKey("Category.category_id"), nullable=False)
    name = Column(String(100), nullable=False)
    description = Column(Text, nullable=True)
    stock = Column(Integer, nullable=False, default=0)

class RentalReason(Base):
    __tablename__ = "Rental_Reason"

    rental_reason_id = Column(Integer, primary_key=True)
    description = Column(String(255), nullable=False)

class RentalRecord(Base):
    __tablename__ = "Rental_Record"

    # Composite Primary Key (student_id + equipment_id) based on ERD
    student_id = Column(Integer, ForeignKey("Student.student_id"), primary_key=True)
    equipment_id = Column(Integer, ForeignKey("Equipment.equipment_id"), primary_key=True)
    
    rental_reason_id = Column(Integer, ForeignKey("Rental_Reason.rental_reason_id"), nullable=False)
    collection_date = Column(DateTime, nullable=False)
    return_date = Column(DateTime, nullable=True)
    status = Column(String(50), default="Pending")
    rental_duration = Column(Integer, nullable=True)
    return_status = Column(String(50), nullable=True)
    proof_of_status = Column(String(255), nullable=True)

class CancellationReason(Base):
    __tablename__ = "Cancellation_Reason"

    reason_id = Column(Integer, primary_key=True)
    description = Column(String(255), nullable=False)

class Appointment(Base):
    __tablename__ = "Appointment"

    appointment_id = Column(Integer, primary_key=True)
    therapist_id = Column(Integer, ForeignKey("Physiotherapist.therapist_id"), nullable=False)
    student_id = Column(Integer, ForeignKey("Student.student_id"), nullable=False)
    reason_id = Column(Integer, ForeignKey("Cancellation_Reason.reason_id"), nullable=True)
    
    schedule_time = Column(DateTime, nullable=False)
    status = Column(String(50), default="Scheduled")
    evaluation = Column(Text, nullable=True)

class Prescription(Base):
    __tablename__ = "Prescription"

    prescription_id = Column(Integer, primary_key=True)
    appointment_id = Column(Integer, ForeignKey("Appointment.appointment_id"), nullable=False)
    student_id = Column(Integer, ForeignKey("Student.student_id"), nullable=False)
    therapist_id = Column(Integer, ForeignKey("Physiotherapist.therapist_id"), nullable=False)
    
    diagnosis = Column(Text, nullable=True)
    status = Column(String(50), default="Active")

class Exercise(Base):
    __tablename__ = "Exercise"

    exercise_id = Column(Integer, primary_key=True)
    name = Column(String(100), nullable=False)
    description = Column(Text, nullable=True)
    discipline = Column(String(100), nullable=True)
    reference_joint_angle = Column(Float, nullable=True)

class PrescribedExercise(Base):
    __tablename__ = "Prescribed_Exercise"

    prescribed_exercise_id = Column(Integer, primary_key=True)
    exercise_id = Column(Integer, ForeignKey("Exercise.exercise_id"), nullable=False)
    prescription_id = Column(Integer, ForeignKey("Prescription.prescription_id"), nullable=False)
    
    assigned_sets = Column(Integer, nullable=False)
    assigned_duration = Column(Integer, nullable=False)
    evaluation = Column(Text, nullable=True)

class AIFeedback(Base):
    __tablename__ = "Ai_Feedback"

    feedback_id = Column(Integer, primary_key=True)
    prescribed_exercise_id = Column(Integer, ForeignKey("Prescribed_Exercise.prescribed_exercise_id"), nullable=False)
    
    joint_angle = Column(Float, nullable=False)
    accuracy_score = Column(Float, nullable=False)
    deviation_score = Column(Float, nullable=False)
    timestamp = Column(DateTime, default=datetime.utcnow)

class LiveChatSession(Base):
    __tablename__ = "Live_Chat_Session"

    session_id = Column(Integer, primary_key=True)
    therapist_id = Column(Integer, ForeignKey("Physiotherapist.therapist_id"), nullable=False)
    student_id = Column(Integer, ForeignKey("Student.student_id"), nullable=False)
    
    subject = Column(String(255), nullable=True)
    session_status = Column(String(50), default="Active")
    created_at = Column(DateTime, default=datetime.utcnow)

class ChatLog(Base):
    __tablename__ = "Chat_Log"

    chat_id = Column(Integer, primary_key=True)
    session_id = Column(Integer, ForeignKey("Live_Chat_Session.session_id"), nullable=False)
    
    content = Column(Text, nullable=False)
    timestamp = Column(DateTime, default=datetime.utcnow)

