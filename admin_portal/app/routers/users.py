from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from sqlalchemy import text
from typing import Optional
from pydantic import BaseModel
from datetime import datetime
from ..database import get_db
from ..services.auth import get_current_admin

router = APIRouter(prefix="/api/users", tags=["users"])


class BanUserRequest(BaseModel):
    reason: str
    duration_days: Optional[int] = None  # None = permanent


class UserResponse(BaseModel):
    id: int
    username: str
    email: str
    full_name: Optional[str]
    is_online: bool
    created_at: datetime
    is_banned: bool
    ban_reason: Optional[str]


@router.get("/")
async def get_users(
    search: Optional[str] = None,
    is_banned: Optional[bool] = None,
    limit: int = 50,
    offset: int = 0,
    db: Session = Depends(get_db),
    admin: dict = Depends(get_current_admin)
):
    """Get users list with filters"""
    query = """
        SELECT
            u.id,
            u.username,
            u.email,
            u.full_name,
            u.is_online,
            u.created_at,
            u.deleted_at,
            CASE WHEN ub.id IS NOT NULL AND (ub.expires_at IS NULL OR ub.expires_at > NOW()) THEN true ELSE false END as is_banned,
            ub.reason as ban_reason,
            (SELECT COUNT(*) FROM messages WHERE sender_id = u.id) as message_count,
            (SELECT COUNT(*) FROM content_reports WHERE reported_user_id = u.id) as report_count
        FROM users u
        LEFT JOIN user_bans ub ON u.id = ub.user_id
        WHERE u.deleted_at IS NULL
    """
    params = {}

    if search:
        query += " AND (u.username ILIKE :search OR u.email ILIKE :search OR u.full_name ILIKE :search)"
        params["search"] = f"%{search}%"

    if is_banned is not None:
        if is_banned:
            query += " AND ub.id IS NOT NULL AND (ub.expires_at IS NULL OR ub.expires_at > NOW())"
        else:
            query += " AND (ub.id IS NULL OR ub.expires_at < NOW())"

    query += " ORDER BY u.created_at DESC LIMIT :limit OFFSET :offset"
    params["limit"] = limit
    params["offset"] = offset

    result = db.execute(text(query), params)
    users = result.fetchall()

    return [dict(row._mapping) for row in users]


@router.get("/stats")
async def get_user_stats(
    db: Session = Depends(get_db),
    admin: dict = Depends(get_current_admin)
):
    """Get user statistics"""
    stats_query = """
        SELECT
            COUNT(*) as total_users,
            COUNT(*) FILTER (WHERE is_online = true) as online_users,
            COUNT(*) FILTER (WHERE created_at > NOW() - INTERVAL '24 hours') as new_today,
            COUNT(*) FILTER (WHERE created_at > NOW() - INTERVAL '7 days') as new_this_week,
            (SELECT COUNT(*) FROM user_bans WHERE expires_at IS NULL OR expires_at > NOW()) as banned_users
        FROM users
        WHERE deleted_at IS NULL
    """
    result = db.execute(text(stats_query))
    row = result.fetchone()

    return dict(row._mapping) if row else {}


@router.get("/{user_id}")
async def get_user(
    user_id: int,
    db: Session = Depends(get_db),
    admin: dict = Depends(get_current_admin)
):
    """Get user details"""
    query = """
        SELECT
            u.*,
            CASE WHEN ub.id IS NOT NULL AND (ub.expires_at IS NULL OR ub.expires_at > NOW()) THEN true ELSE false END as is_banned,
            ub.reason as ban_reason,
            ub.created_at as banned_at,
            ub.expires_at as ban_expires,
            (SELECT COUNT(*) FROM messages WHERE sender_id = u.id) as message_count,
            (SELECT COUNT(*) FROM content_reports WHERE reported_user_id = u.id) as reports_received,
            (SELECT COUNT(*) FROM content_reports WHERE reporter_id = u.id) as reports_sent
        FROM users u
        LEFT JOIN user_bans ub ON u.id = ub.user_id
        WHERE u.id = :user_id
    """
    result = db.execute(text(query), {"user_id": user_id})
    user = result.fetchone()

    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    return dict(user._mapping)


@router.post("/{user_id}/ban")
async def ban_user(
    user_id: int,
    request: BanUserRequest,
    db: Session = Depends(get_db),
    admin: dict = Depends(get_current_admin)
):
    """Ban a user"""
    # Check if user exists
    user_check = db.execute(text("SELECT id FROM users WHERE id = :user_id"), {"user_id": user_id})
    if not user_check.fetchone():
        raise HTTPException(status_code=404, detail="User not found")

    # Remove existing bans
    db.execute(text("DELETE FROM user_bans WHERE user_id = :user_id"), {"user_id": user_id})

    # Create new ban
    expires_at = None
    if request.duration_days:
        expires_at = f"NOW() + INTERVAL '{request.duration_days} days'"
        ban_query = f"""
            INSERT INTO user_bans (user_id, banned_by, reason, expires_at, created_at)
            VALUES (
                :user_id,
                (SELECT id FROM users WHERE username = :admin_username LIMIT 1),
                :reason,
                {expires_at},
                NOW()
            )
        """
    else:
        ban_query = """
            INSERT INTO user_bans (user_id, banned_by, reason, created_at)
            VALUES (
                :user_id,
                (SELECT id FROM users WHERE username = :admin_username LIMIT 1),
                :reason,
                NOW()
            )
        """

    db.execute(text(ban_query), {
        "user_id": user_id,
        "admin_username": admin["sub"],
        "reason": request.reason
    })

    # Set user offline
    db.execute(text("UPDATE users SET is_online = false WHERE id = :user_id"), {"user_id": user_id})

    db.commit()
    return {"success": True, "message": "User banned successfully"}


@router.post("/{user_id}/unban")
async def unban_user(
    user_id: int,
    db: Session = Depends(get_db),
    admin: dict = Depends(get_current_admin)
):
    """Unban a user"""
    result = db.execute(text("DELETE FROM user_bans WHERE user_id = :user_id"), {"user_id": user_id})
    db.commit()

    return {"success": True, "message": "User unbanned successfully"}


@router.get("/{user_id}/messages")
async def get_user_messages(
    user_id: int,
    limit: int = 50,
    db: Session = Depends(get_db),
    admin: dict = Depends(get_current_admin)
):
    """Get user's recent messages"""
    query = """
        SELECT
            m.id,
            m.content,
            m.type,
            m.created_at,
            c.name as chat_name,
            c.type as chat_type
        FROM messages m
        JOIN chats c ON m.chat_id = c.id
        WHERE m.sender_id = :user_id
        ORDER BY m.created_at DESC
        LIMIT :limit
    """
    result = db.execute(text(query), {"user_id": user_id, "limit": limit})
    messages = result.fetchall()

    return [dict(row._mapping) for row in messages]
