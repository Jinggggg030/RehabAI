from backend.database import engine
from sqlalchemy import text

def enable_realtime():
    with engine.connect() as conn:
        try:
            conn.execute(text('ALTER PUBLICATION supabase_realtime ADD TABLE "Chat_Log";'))
            conn.execute(text('ALTER PUBLICATION supabase_realtime ADD TABLE "Live_Chat_Session";'))
            conn.commit()
            print("Realtime enabled successfully.")
        except Exception as e:
            print(f"Error: {e}")

if __name__ == "__main__":
    enable_realtime()
