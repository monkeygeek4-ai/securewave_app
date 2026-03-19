from fastapi import APIRouter, HTTPException, status, Response, Request, Form
from fastapi.responses import RedirectResponse
from pydantic import BaseModel
from ..services.auth import verify_password, create_access_token, get_password_hash
from ..config import settings

router = APIRouter(prefix="/auth", tags=["auth"])


class LoginRequest(BaseModel):
    username: str
    password: str


# Hardcoded admin for now (in production, store in DB)
ADMIN_USERS = {
    "admin": {
        "password_hash": get_password_hash("SecureAdmin2024!"),
        "is_admin": True,
        "role": "superadmin"
    },
    "moderator": {
        "password_hash": get_password_hash("Moderator2024!"),
        "is_admin": True,
        "role": "moderator"
    }
}


@router.post("/login")
async def login(response: Response, username: str = Form(...), password: str = Form(...)):
    user = ADMIN_USERS.get(username)

    if not user or not verify_password(password, user["password_hash"]):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password"
        )

    token = create_access_token({
        "sub": username,
        "is_admin": True,
        "role": user["role"]
    })

    # Set cookie and redirect to dashboard
    redirect = RedirectResponse(url="/dashboard", status_code=302)
    redirect.set_cookie(
        key="admin_token",
        value=token,
        httponly=True,
        max_age=86400,  # 24 hours
        samesite="lax"
    )
    return redirect


@router.post("/api/login")
async def api_login(request: LoginRequest):
    """API login endpoint for programmatic access"""
    user = ADMIN_USERS.get(request.username)

    if not user or not verify_password(request.password, user["password_hash"]):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password"
        )

    token = create_access_token({
        "sub": request.username,
        "is_admin": True,
        "role": user["role"]
    })

    return {"access_token": token, "token_type": "bearer"}


@router.get("/logout")
async def logout():
    response = RedirectResponse(url="/login", status_code=302)
    response.delete_cookie("admin_token")
    return response
