from fastapi import APIRouter, Depends, HTTPException
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session

from app.database import get_db
from app.models import Item, ItemSchema
from app.core.config import settings

router = APIRouter()
security = HTTPBearer()

@router.get("/health", tags=["health"])
async def health_check():
    """
    Health check endpoint to verify if the API is running.
    """
    return {"status": "healthy"}


@router.get("/items", response_model=list[ItemSchema], tags=["items"])
def read_items(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: Session = Depends(get_db),
):
    """Protected endpoint returning all items from the database."""
    if credentials.credentials != settings.API_TOKEN:
        raise HTTPException(status_code=401, detail="Invalid token")
    return db.query(Item).all()
