from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from sqlalchemy import text
from typing import List, Optional
from pydantic import BaseModel
from datetime import datetime
from ..database import get_db
from ..services.auth import get_current_admin

router = APIRouter(prefix="/api/reports", tags=["reports"])


class ReportResponse(BaseModel):
    id: int
    reporter_id: int
    reporter_username: str
    reported_user_id: int
    reported_username: str
    message_id: Optional[int]
    message_content: Optional[str]
    chat_id: Optional[int]
    report_type: str
    description: Optional[str]
    status: str
    moderator_notes: Optional[str]
    created_at: datetime

    class Config:
        from_attributes = True


class UpdateReportRequest(BaseModel):
    status: str
    moderator_notes: Optional[str] = None
    action: Optional[str] = None  # "ban_user", "delete_message", "warn_user"


@router.get("/")
async def get_reports(
    status_filter: Optional[str] = Query(None, alias="status"),
    report_type: Optional[str] = None,
    limit: int = 50,
    offset: int = 0,
    db: Session = Depends(get_db),
    admin: dict = Depends(get_current_admin)
):
    """Get all content reports with filters"""
    query = """
        SELECT
            cr.id,
            cr.reporter_id,
            reporter.username as reporter_username,
            cr.reported_user_id,
            reported.username as reported_username,
            cr.message_id,
            m.content as message_content,
            cr.chat_id,
            cr.report_type,
            cr.description,
            cr.status,
            cr.moderator_notes,
            cr.created_at
        FROM content_reports cr
        JOIN users reporter ON cr.reporter_id = reporter.id
        JOIN users reported ON cr.reported_user_id = reported.id
        LEFT JOIN messages m ON cr.message_id = m.id
        WHERE 1=1
    """
    params = {}

    if status_filter:
        query += " AND cr.status = :status"
        params["status"] = status_filter

    if report_type:
        query += " AND cr.report_type = :report_type"
        params["report_type"] = report_type

    query += " ORDER BY cr.created_at DESC LIMIT :limit OFFSET :offset"
    params["limit"] = limit
    params["offset"] = offset

    result = db.execute(text(query), params)
    reports = result.fetchall()

    return [dict(row._mapping) for row in reports]


@router.get("/stats")
async def get_report_stats(
    db: Session = Depends(get_db),
    admin: dict = Depends(get_current_admin)
):
    """Get report statistics for dashboard"""
    stats_query = """
        SELECT
            COUNT(*) FILTER (WHERE status = 'pending') as pending_count,
            COUNT(*) FILTER (WHERE status = 'reviewed') as reviewed_count,
            COUNT(*) FILTER (WHERE status = 'resolved') as resolved_count,
            COUNT(*) FILTER (WHERE status = 'dismissed') as dismissed_count,
            COUNT(*) as total_count,
            COUNT(*) FILTER (WHERE created_at > NOW() - INTERVAL '24 hours') as last_24h
        FROM content_reports
    """
    result = db.execute(text(stats_query))
    row = result.fetchone()

    return dict(row._mapping) if row else {}


@router.get("/{report_id}")
async def get_report(
    report_id: int,
    db: Session = Depends(get_db),
    admin: dict = Depends(get_current_admin)
):
    """Get single report details"""
    query = """
        SELECT
            cr.*,
            reporter.username as reporter_username,
            reporter.email as reporter_email,
            reported.username as reported_username,
            reported.email as reported_email,
            m.content as message_content,
            m.type as message_type
        FROM content_reports cr
        JOIN users reporter ON cr.reporter_id = reporter.id
        JOIN users reported ON cr.reported_user_id = reported.id
        LEFT JOIN messages m ON cr.message_id = m.id
        WHERE cr.id = :report_id
    """
    result = db.execute(text(query), {"report_id": report_id})
    report = result.fetchone()

    if not report:
        raise HTTPException(status_code=404, detail="Report not found")

    return dict(report._mapping)


@router.put("/{report_id}")
async def update_report(
    report_id: int,
    request: UpdateReportRequest,
    db: Session = Depends(get_db),
    admin: dict = Depends(get_current_admin)
):
    """Update report status and take action"""
    # Update report
    update_query = """
        UPDATE content_reports
        SET status = :status,
            moderator_notes = :notes,
            moderator_id = (SELECT id FROM users WHERE username = :admin_username LIMIT 1),
            updated_at = NOW()
        WHERE id = :report_id
        RETURNING id
    """
    result = db.execute(text(update_query), {
        "status": request.status,
        "notes": request.moderator_notes,
        "admin_username": admin["sub"],
        "report_id": report_id
    })

    if not result.fetchone():
        raise HTTPException(status_code=404, detail="Report not found")

    # Take action if specified
    if request.action == "ban_user":
        # Get reported user ID
        user_query = "SELECT reported_user_id FROM content_reports WHERE id = :report_id"
        user_result = db.execute(text(user_query), {"report_id": report_id})
        user_row = user_result.fetchone()

        if user_row:
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
                "user_id": user_row.reported_user_id,
                "admin_username": admin["sub"],
                "reason": request.moderator_notes or "Violation of community guidelines"
            })

    elif request.action == "delete_message":
        # Get message ID and delete
        msg_query = "SELECT message_id FROM content_reports WHERE id = :report_id"
        msg_result = db.execute(text(msg_query), {"report_id": report_id})
        msg_row = msg_result.fetchone()

        if msg_row and msg_row.message_id:
            delete_query = "DELETE FROM messages WHERE id = :message_id"
            db.execute(text(delete_query), {"message_id": msg_row.message_id})

    db.commit()
    return {"success": True, "message": "Report updated successfully"}
