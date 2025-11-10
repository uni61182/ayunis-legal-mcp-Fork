"""
Main FastAPI application module
"""

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
import os
import uuid
import logging

from app.routers import legal_texts

# from app.database import async_engine, Base

# Configure logging
logging.basicConfig(
    level=logging.INFO, format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)


# @asynccontextmanager
# async def lifespan(app: FastAPI):
#     """
#     Lifespan context manager for startup and shutdown events
#     """
#     # Startup
#     logger.info("Starting Legal MCP API...")

#     # Create database tables
#     try:
#         async with async_engine.begin() as conn:
#             await conn.run_sync(Base.metadata.create_all)
#         logger.info("Database tables created successfully")
#     except Exception as e:
#         logger.error(f"Error creating database tables: {e}")

#     yield

#     # Shutdown
#     logger.info("Shutting down Legal MCP API...")
#     await async_engine.dispose()


app = FastAPI(
    title="Legal MCP API",
    description="A modern FastAPI application for importing and querying German legal texts using vector search",
    version="0.2.0",
    # lifespan=lifespan,
)

# Include routers
app.include_router(legal_texts.router)


# Security: Request size limits to prevent memory exhaustion
MAX_REQUEST_SIZE = 10 * 1024 * 1024  # 10 MB


@app.middleware("http")
async def limit_request_size(request: Request, call_next):
    """
    Middleware to limit request body size and prevent memory exhaustion attacks

    Checks the Content-Length header for POST, PUT, and PATCH requests
    and rejects requests that exceed MAX_REQUEST_SIZE (10 MB).
    """
    if request.method in ["POST", "PUT", "PATCH"]:
        content_length = request.headers.get("content-length")
        if content_length and int(content_length) > MAX_REQUEST_SIZE:
            logger.warning(
                f"Request rejected: body too large ({content_length} bytes, max {MAX_REQUEST_SIZE})"
            )
            return JSONResponse(
                status_code=413,
                content={
                    "detail": f"Request body too large. Maximum size is {MAX_REQUEST_SIZE // (1024 * 1024)} MB."
                }
            )

    return await call_next(request)


@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    """
    Global exception handler to prevent information leakage in production

    In production mode (ENVIRONMENT=production), hides detailed error messages
    and returns a generic error response with a unique error ID for tracking.

    In development mode, returns detailed error information for debugging.
    """
    # Log the full error details
    error_id = str(uuid.uuid4())
    logger.error(
        f"Unhandled exception (Error ID: {error_id}): {str(exc)}",
        exc_info=True,
        extra={"error_id": error_id, "path": request.url.path}
    )

    # Check if we're in production mode
    environment = os.getenv("ENVIRONMENT", "development").lower()

    if environment == "production":
        # In production, hide details and return generic error
        return JSONResponse(
            status_code=500,
            content={
                "detail": "An internal error occurred. Please try again later.",
                "error_id": error_id,
                "support": "If this error persists, please report it with the error ID above."
            },
        )
    else:
        # In development, show details for debugging
        return JSONResponse(
            status_code=500,
            content={
                "detail": str(exc),
                "error_id": error_id,
                "type": type(exc).__name__
            },
        )


@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {"status": "healthy", "version": "0.2.0"}
