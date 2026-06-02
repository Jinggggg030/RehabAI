import asyncio
from backend.database import engine
from backend.models import LiveChatSession, ChatLog, Base

def recreate_tables():
    # Drop only the chat tables
    print("Dropping Chat tables...")
    ChatLog.__table__.drop(engine, checkfirst=True)
    LiveChatSession.__table__.drop(engine, checkfirst=True)
    
    # Recreate all missing tables (including the ones we just dropped, with new schema)
    print("Recreating tables...")
    Base.metadata.create_all(bind=engine)
    print("Done!")

if __name__ == "__main__":
    recreate_tables()
