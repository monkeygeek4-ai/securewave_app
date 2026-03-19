from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware
from .routers import auth_router, reports_router, users_router, moderation_router, pages_router
from .config import settings

app = FastAPI(
    title="SecureWave Admin Portal",
    description="Moderation and administration panel for SecureWave messenger",
    version="1.0.0"
)

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Static files
app.mount("/static", StaticFiles(directory="static"), name="static")

# Routers
app.include_router(auth_router)
app.include_router(reports_router)
app.include_router(users_router)
app.include_router(moderation_router)
app.include_router(pages_router)


@app.get("/health")
async def health_check():
    return {"status": "ok", "service": "SecureWave Admin Portal"}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host=settings.HOST, port=settings.PORT)
