from backend.database import engine
from sqlalchemy import text

def grant_perms():
    with engine.connect() as conn:
        conn.execute(text('GRANT ALL PRIVILEGES ON "Chat_Log" TO anon, authenticated;'))
        conn.execute(text('GRANT USAGE, SELECT ON SEQUENCE "Chat_Log_chat_id_seq" TO anon, authenticated;'))
        conn.execute(text('GRANT ALL PRIVILEGES ON "Live_Chat_Session" TO anon, authenticated;'))
        conn.execute(text('GRANT USAGE, SELECT ON SEQUENCE "Live_Chat_Session_session_id_seq" TO anon, authenticated;'))
        conn.commit()
    print("Permissions granted successfully.")

if __name__ == "__main__":
    grant_perms()
