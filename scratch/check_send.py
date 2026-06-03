import requests

res = requests.post('http://127.0.0.1:8000/chat/send', json={
    "session_id": 3,
    "user_id": 1,
    "message": "a few weeks"
})
print(res.status_code)
print(res.text)
