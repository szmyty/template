from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    PROJECT_NAME: str = "FastAPI Application"
    PROJECT_DESCRIPTION: str = "A FastAPI application with a custom configuration."
    PROJECT_VERSION: str = "1.0.0"
    ALLOWED_HOSTS: list[str] = ["*"]
    DEBUG: bool = False
    DATABASE_URL: str = "sqlite:///./test.db"

    # Keycloak configuration. These values can be overridden via environment
    # variables to point the service at your Keycloak instance.
    KEYCLOAK_SERVER_URL: str = "http://localhost:8080/"
    KEYCLOAK_REALM: str = "master"
    KEYCLOAK_CLIENT_ID: str = "fastapi"
    KEYCLOAK_CLIENT_SECRET: str | None = None
    KEYCLOAK_ADMIN_CLIENT_SECRET: str | None = None
    KEYCLOAK_CALLBACK_URI: str = "http://localhost:8000/auth/callback"

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"


settings = Settings()
