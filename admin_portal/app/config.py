import os
from dotenv import load_dotenv

load_dotenv()

class Settings:
    DATABASE_URL: str = os.getenv("DATABASE_URL", "postgresql://wave_user:WaveSecure2024@localhost:5432/securewave_db")
    JWT_SECRET: str = os.getenv("JWT_SECRET", "SW2024$ecureW@ve!K3y#9x7mNp4qR8tUv2wXyZ")
    ADMIN_USERNAME: str = os.getenv("ADMIN_USERNAME", "admin")
    ADMIN_PASSWORD_HASH: str = os.getenv("ADMIN_PASSWORD_HASH", "")
    HOST: str = os.getenv("HOST", "0.0.0.0")
    PORT: int = int(os.getenv("PORT", "8000"))

settings = Settings()
