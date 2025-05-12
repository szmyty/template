from fastapi import APIRouter

router = APIRouter()

@router.get("/health", tags=["health"])
async def health_check():
    """
    Health check endpoint to verify if the API is running.
    """
    return {"status": "healthy"}
