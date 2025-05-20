from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    PROJECT_NAME: str = "FastAPI Application"
    PROJECT_DESCRIPTION: str = "A FastAPI application with a custom configuration."
    PROJECT_VERSION: str = "1.0.0"
    ALLOWED_HOSTS: list[str] = ["*"]
    DEBUG: bool = False
    DATABASE_URL: str = "sqlite:///./test.db"
    API_TOKEN: str = "secret-token"

class Config:
    env_file = ".env"
    env_file_encoding = "utf-8"


settings = Settings()
