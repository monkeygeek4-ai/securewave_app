from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import text
from typing import List
from pydantic import BaseModel
from ..database import get_db
from ..services.auth import get_current_admin

router = APIRouter(prefix="/api/moderation", tags=["moderation"])


class DeleteMessageRequest(BaseModel):
    message_ids: List[int]
    reason: str


class DeleteChatRequest(BaseModel):
    chat_id: int
    reason: str


@router.post("/messages/delete")
async def delete_messages(
    request: DeleteMessageRequest,
    db: Session = Depends(get_db),
    admin: dict = Depends(get_current_admin)
):
    """Delete multiple messages"""
    if not request.message_ids:
        raise HTTPException(status_code=400, detail="No message IDs provided")

    # Log the deletion
    for msg_id in request.message_ids:
        log_query = """
            INSERT INTO moderation_log (action, target_type, target_id, admin_username, reason, created_at)
            VALUES ('delete', 'message', :msg_id, :admin, :reason, NOW())
        """
        try:
            db.execute(text(log_query), {
                "msg_id": msg_id,
                "admin": admin["sub"],
                "reason": request.reason
            })
        except:
            pass  # Log table might not exist

    # Delete messages
    delete_query = "DELETE FROM messages WHERE id = ANY(:ids)"
    db.execute(text(delete_query), {"ids": request.message_ids})
    db.commit()

    return {"success": True, "deleted_count": len(request.message_ids)}


@router.post("/chats/delete")
async def delete_chat(
    request: DeleteChatRequest,
    db: Session = Depends(get_db),
    admin: dict = Depends(get_current_admin)
):
    """Delete entire chat with all messages"""
    # Delete messages first
    db.execute(text("DELETE FROM messages WHERE chat_id = :chat_id"), {"chat_id": request.chat_id})

    # Delete chat members
    db.execute(text("DELETE FROM chat_members WHERE chat_id = :chat_id"), {"chat_id": request.chat_id})

    # Delete chat
    result = db.execute(text("DELETE FROM chats WHERE id = :chat_id RETURNING id"), {"chat_id": request.chat_id})

    if not result.fetchone():
        raise HTTPException(status_code=404, detail="Chat not found")

    db.commit()
    return {"success": True, "message": "Chat deleted successfully"}


@router.get("/flagged-content")
async def get_flagged_content(
    db: Session = Depends(get_db),
    admin: dict = Depends(get_current_admin)
):
    """Get potentially flagged content (messages with bad words)"""
    # Simple word filter - in production use ML model or better filtering
    bad_words = ['spam', 'scam', 'xxx', 'porn']

    conditions = " OR ".join([f"LOWER(content) LIKE '%{word}%'" for word in bad_words])

    query = f"""
        SELECT
            m.id,
            m.content,
            m.type,
            m.created_at,
            u.username as sender_username,
            u.id as sender_id,
            c.name as chat_name
        FROM messages m
        JOIN users u ON m.sender_id = u.id
        JOIN chats c ON m.chat_id = c.id
        WHERE ({conditions})
        ORDER BY m.created_at DESC
        LIMIT 100
    """
    result = db.execute(text(query))
    messages = result.fetchall()

    return [dict(row._mapping) for row in messages]


@router.get("/activity-log")
async def get_activity_log(
    limit: int = 100,
    db: Session = Depends(get_db),
    admin: dict = Depends(get_current_admin)
):
    """Get moderation activity log"""
    # Try to get from moderation_log table
    try:
        query = """
            SELECT * FROM moderation_log
            ORDER BY created_at DESC
            LIMIT :limit
        """
        result = db.execute(text(query), {"limit": limit})
        logs = result.fetchall()
        return [dict(row._mapping) for row in logs]
    except:
        return []  # Table doesn't exist yet
