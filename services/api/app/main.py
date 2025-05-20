from fastapi import FastAPI, Request, Depends
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from starlette.exceptions import HTTPException
from starlette.status import HTTP_404_NOT_FOUND
from fastapi_keycloak import FastAPIKeycloak
from app.api.routes import router as api_router
from app.core.config import settings

app = FastAPI(
    title=settings.PROJECT_NAME,
    description=settings.PROJECT_DESCRIPTION,
    version=settings.PROJECT_VERSION,
)

# Initialize Keycloak integration. These values are loaded from environment
# variables via the Settings class.
keycloak = FastAPIKeycloak(
    server_url=settings.KEYCLOAK_SERVER_URL,
    client_id=settings.KEYCLOAK_CLIENT_ID,
    client_secret=settings.KEYCLOAK_CLIENT_SECRET,
    admin_client_secret=settings.KEYCLOAK_ADMIN_CLIENT_SECRET,
    realm=settings.KEYCLOAK_REALM,
    callback_uri=settings.KEYCLOAK_CALLBACK_URI,
)

app.include_router(api_router, tags=["api"])
app.include_router(keycloak.get_auth_router(), prefix="/auth", tags=["auth"])

@app.get("/")
async def root():
    return {"message": "Welcome to the FastAPI application!"}


# Example protected endpoint. It uses the ``get_current_user`` dependency from
# ``fastapi_keycloak`` to ensure that only authenticated users can access the
# route.
@app.get("/protected", tags=["api"])
async def protected_route(user=Depends(keycloak.get_current_user())):
    return {"message": f"Hello, {user.username}!"}

@app.exception_handler(HTTPException)
async def http_exception_handler(request: Request, exc: HTTPException):
    if exc.status_code == HTTP_404_NOT_FOUND:
        return JSONResponse(
            status_code=exc.status_code,
            content={"detail": "Resource not found."},
        )

    return JSONResponse(
        status_code=exc.status_code,
        content={"detail": exc.detail},
    )
