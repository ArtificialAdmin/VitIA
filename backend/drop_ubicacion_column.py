import os
from sqlalchemy import create_engine, text
from dotenv import load_dotenv

load_dotenv()

DATABASE_URL = os.getenv("DATABASE_URL")

def migrate():
    if not DATABASE_URL:
        print("Error: DATABASE_URL not found in .env")
        return

    print(f"Connecting to database to DROP 'ubicacion'...")
    engine = create_engine(DATABASE_URL)
    
    with engine.connect() as conn:
        print("Dropping 'ubicacion' column from 'Usuarios'...")
        try:
            conn.execute(text("ALTER TABLE \"Usuarios\" DROP COLUMN ubicacion;"))
            conn.commit()
            print("Column 'ubicacion' dropped successfully.")
        except Exception as e:
            print(f"Error dropping 'ubicacion': {e}")

    print("Migration finished.")

if __name__ == "__main__":
    migrate()
