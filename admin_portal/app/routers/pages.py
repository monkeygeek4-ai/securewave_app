from fastapi import APIRouter, Request, Depends
from fastapi.responses import HTMLResponse, RedirectResponse
from fastapi.templating import Jinja2Templates
from sqlalchemy.orm import Session
from sqlalchemy import text
from ..database import get_db
from ..services.auth import get_current_admin, decode_token

router = APIRouter(tags=["pages"])
templates = Jinja2Templates(directory="app/templates")


def get_optional_admin(request: Request):
    """Get admin if logged in, otherwise None"""
    token = request.cookies.get("admin_token")
    if not token:
        return None
    payload = decode_token(token)
    if not payload or not payload.get("is_admin"):
        return None
    return payload


@router.get("/", response_class=HTMLResponse)
async def root(request: Request):
    admin = get_optional_admin(request)
    if admin:
        return RedirectResponse(url="/dashboard", status_code=302)
    return RedirectResponse(url="/login", status_code=302)


@router.get("/login", response_class=HTMLResponse)
async def login_page(request: Request):
    admin = get_optional_admin(request)
    if admin:
        return RedirectResponse(url="/dashboard", status_code=302)
    return templates.TemplateResponse("login.html", {"request": request})


@router.get("/dashboard", response_class=HTMLResponse)
async def dashboard(
    request: Request,
    db: Session = Depends(get_db)
):
    admin = get_optional_admin(request)
    if not admin:
        return RedirectResponse(url="/login", status_code=302)

    # Get stats
    try:
        stats = {}

        # User stats
        user_stats = db.execute(text("""
            SELECT
                COUNT(*) as total_users,
                COUNT(*) FILTER (WHERE is_online = true) as online_users,
                COUNT(*) FILTER (WHERE created_at > NOW() - INTERVAL '24 hours') as new_today
            FROM users WHERE deleted_at IS NULL
        """))
        row = user_stats.fetchone()
        if row:
            stats.update(dict(row._mapping))

        # Report stats
        report_stats = db.execute(text("""
            SELECT
                COUNT(*) FILTER (WHERE status = 'pending') as pending_reports,
                COUNT(*) as total_reports
            FROM content_reports
        """))
        row = report_stats.fetchone()
        if row:
            stats.update(dict(row._mapping))

        # Message stats
        msg_stats = db.execute(text("""
            SELECT COUNT(*) as total_messages FROM messages
        """))
        row = msg_stats.fetchone()
        if row:
            stats.update(dict(row._mapping))

    except Exception as e:
        stats = {
            "total_users": 0,
            "online_users": 0,
            "new_today": 0,
            "pending_reports": 0,
            "total_reports": 0,
            "total_messages": 0
        }

    return templates.TemplateResponse("dashboard.html", {
        "request": request,
        "admin": admin,
        "stats": stats
    })


@router.get("/reports", response_class=HTMLResponse)
async def reports_page(
    request: Request,
    db: Session = Depends(get_db)
):
    admin = get_optional_admin(request)
    if not admin:
        return RedirectResponse(url="/login", status_code=302)

    # Get reports
    try:
        result = db.execute(text("""
            SELECT
                cr.id,
                cr.report_type,
                cr.description,
                cr.status,
                cr.created_at,
                reporter.username as reporter_username,
                reported.username as reported_username,
                m.content as message_content,
                m.media_url as message_media_url,
                m.type as message_type
            FROM content_reports cr
            JOIN users reporter ON cr.reporter_id = reporter.id
            JOIN users reported ON cr.reported_user_id = reported.id
            LEFT JOIN messages m ON cr.message_id = m.id
            ORDER BY
                CASE cr.status WHEN 'pending' THEN 0 ELSE 1 END,
                cr.created_at DESC
            LIMIT 100
        """))
        reports = [dict(row._mapping) for row in result.fetchall()]
    except:
        reports = []

    return templates.TemplateResponse("reports.html", {
        "request": request,
        "admin": admin,
        "reports": reports
    })


@router.get("/users", response_class=HTMLResponse)
async def users_page(
    request: Request,
    db: Session = Depends(get_db)
):
    admin = get_optional_admin(request)
    if not admin:
        return RedirectResponse(url="/login", status_code=302)

    # Get users
    try:
        result = db.execute(text("""
            SELECT
                u.id,
                u.username,
                u.email,
                u.full_name,
                u.is_online,
                u.created_at,
                CASE WHEN ub.id IS NOT NULL THEN true ELSE false END as is_banned,
                (SELECT COUNT(*) FROM content_reports WHERE reported_user_id = u.id) as report_count
            FROM users u
            LEFT JOIN user_bans ub ON u.id = ub.user_id AND (ub.expires_at IS NULL OR ub.expires_at > NOW())
            WHERE u.deleted_at IS NULL
            ORDER BY u.created_at DESC
            LIMIT 100
        """))
        users = [dict(row._mapping) for row in result.fetchall()]
    except:
        users = []

    return templates.TemplateResponse("users.html", {
        "request": request,
        "admin": admin,
        "users": users
    })
