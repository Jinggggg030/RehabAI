import requests

BASE_URL = "https://rehabai-bbmm.onrender.com"


def test_at12_retrieve_exercises():
    response = requests.get(
        f"{BASE_URL}/exercises",
        timeout=30
    )

    assert response.status_code == 200

    data = response.json()

    assert "exercises" in data
    assert isinstance(data["exercises"], list)

def test_at13_reject_invalid_appointment_request():
    invalid_data = {
        "student_id": 1,
        "therapist_id": 2
        # schedule_time is deliberately missing
    }

    response = requests.post(
        f"{BASE_URL}/appointments/book",
        json=invalid_data,
        timeout=30
    )

    assert response.status_code == 422

def test_at14_reject_invalid_rental_request():
    invalid_data = {
        "student_id": 1,
        "rental_reason_id": 1,
        "rental_duration": 7,
        "collection_method": "Self Collection",
        "collection_date": "2026-09-10T10:00:00"
        # equipment_id is missing
    }

    response = requests.post(
        f"{BASE_URL}/rentals/request",
        json=invalid_data,
        timeout=30
    )

    assert response.status_code == 422

def test_at15_retrieve_student_appointments():
    student_id = 4

    response = requests.get(
        f"{BASE_URL}/appointments/student/{student_id}",
        timeout=30
    )

    assert response.status_code == 200

    data = response.json()

    assert "appointments" in data
    assert isinstance(data["appointments"], list)

def test_at16_retrieve_prescribed_exercises():
    student_id = 27

    response = requests.get(
        f"{BASE_URL}/students/{student_id}/prescribed_exercises",
        timeout=30
    )

    assert response.status_code == 200

    data = response.json()

    assert "exercises" in data
    assert isinstance(data["exercises"], list)