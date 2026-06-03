from backend.database import engine
from sqlalchemy import text

def reset_passwords():
    with engine.connect() as conn:
        conn.execute(text("""
            UPDATE auth.users 
            SET encrypted_password = crypt('password123', gen_salt('bf')) 
            WHERE email IN ('yijingchai0319@gmail.com', 'lim123@gmail.com', 'khamarul123@gmail.com');
        """))
        conn.commit()
    print("Passwords successfully reset!")

if __name__ == "__main__":
    reset_passwords()
