from sqlalchemy import Column, Integer, String, DateTime, Text, ForeignKey, Enum
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
import enum
from ..database import Base


class ReportStatus(str, enum.Enum):
    PENDING = "pending"
    REVIEWED = "reviewed"
    RESOLVED = "resolved"
    DISMISSED = "dismissed"


class ReportType(str, enum.Enum):
    SPAM = "spam"
    HARASSMENT = "harassment"
    INAPPROPRIATE = "inappropriate"
    VIOLENCE = "violence"
    HATE_SPEECH = "hate_speech"
    OTHER = "other"


class ContentReport(Base):
    __tablename__ = "content_reports"

    id = Column(Integer, primary_key=True, index=True)
    reporter_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    reported_user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    message_id = Column(Integer, ForeignKey("messages.id"), nullable=True)
    chat_id = Column(Integer, ForeignKey("chats.id"), nullable=True)
    report_type = Column(String(50), nullable=False)
    description = Column(Text, nullable=True)
    status = Column(String(20), default="pending")
    moderator_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    moderator_notes = Column(Text, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())


class UserBlock(Base):
    __tablename__ = "user_blocks"

    id = Column(Integer, primary_key=True, index=True)
    blocker_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    blocked_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    reason = Column(Text, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())


class UserBan(Base):
    __tablename__ = "user_bans"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    banned_by = Column(Integer, ForeignKey("users.id"), nullable=False)
    reason = Column(Text, nullable=False)
    expires_at = Column(DateTime(timezone=True), nullable=True)  # NULL = permanent
    created_at = Column(DateTime(timezone=True), server_default=func.now())
