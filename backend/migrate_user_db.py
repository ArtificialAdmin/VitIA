import os
from sqlalchemy import create_engine, text
from dotenv import load_dotenv

load_dotenv()

DATABASE_URL = os.getenv("DATABASE_URL")

def migrate():
    if not DATABASE_URL:
        print("Error: DATABASE_URL not found in .env")
        return

    print(f"Connecting to database: {DATABASE_URL.split('@')[-1]}") # Log without credentials
    engine = create_engine(DATABASE_URL)
    
    with engine.connect() as conn:
        print("Adding 'latitud' column to 'Usuarios'...")
        try:
            conn.execute(text("ALTER TABLE \"Usuarios\" ADD COLUMN latitud DOUBLE PRECISION;"))
            conn.commit()
            print("Column 'latitud' added.")
        except Exception as e:
            print(f"Error adding 'latitud': {e}")

        print("Adding 'longitud' column to 'Usuarios'...")
        try:
            conn.execute(text("ALTER TABLE \"Usuarios\" ADD COLUMN longitud DOUBLE PRECISION;"))
            conn.commit()
            print("Column 'longitud' added.")
        except Exception as e:
            print(f"Error adding 'longitud': {e}")

    print("Migration finished.")

if __name__ == "__main__":
    migrate()
