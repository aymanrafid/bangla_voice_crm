import uuid
from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from .database import Base


def _uuid() -> str:
    return str(uuid.uuid4())


class TimestampMixin:
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.utcnow, onupdate=datetime.utcnow
    )


class Company(Base, TimestampMixin):
    __tablename__ = 'companies'

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    external_id: Mapped[str] = mapped_column(
        String(36), unique=True, default=_uuid, index=True
    )
    name: Mapped[str] = mapped_column(String(150), unique=True)
    slug: Mapped[str] = mapped_column(String(120), unique=True, index=True)
    status: Mapped[str] = mapped_column(String(30), default='active', index=True)

    users: Mapped[list['User']] = relationship(back_populates='company')


class User(Base, TimestampMixin):
    __tablename__ = 'users'

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    external_id: Mapped[str] = mapped_column(
        String(36), unique=True, default=_uuid, index=True
    )
    company_id: Mapped[int | None] = mapped_column(
        ForeignKey('companies.id'), nullable=True, index=True
    )
    username: Mapped[str] = mapped_column(String(100), unique=True, index=True)
    full_name: Mapped[str] = mapped_column(String(150))
    password_hash: Mapped[str] = mapped_column(String(255))
    role: Mapped[str] = mapped_column(String(30), default='Employee', index=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)

    company: Mapped[Company | None] = relationship(back_populates='users')
    audit_logs: Mapped[list['AuditLog']] = relationship(back_populates='actor')
    password_reset_tokens: Mapped[list['PasswordResetToken']] = relationship(
        back_populates='user'
    )
    uploaded_media: Mapped[list['UploadedMedia']] = relationship(
        back_populates='uploader'
    )

    @property
    def company_external_id(self) -> str:
        return self.company.external_id if self.company else ''

    @property
    def company_name(self) -> str:
        return self.company.name if self.company else ''

    @property
    def company_slug(self) -> str:
        return self.company.slug if self.company else ''


class Lead(Base, TimestampMixin):
    __tablename__ = 'leads'

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    external_id: Mapped[str] = mapped_column(
        String(36), unique=True, default=_uuid, index=True
    )
    company_id: Mapped[int | None] = mapped_column(Integer, nullable=True, index=True)
    lead_type: Mapped[str] = mapped_column(String(50), default='Sales Lead')
    name: Mapped[str] = mapped_column(String(150), default='')
    phone: Mapped[str] = mapped_column(String(30), default='', index=True)
    address: Mapped[str] = mapped_column(Text, default='')
    location: Mapped[str] = mapped_column(String(150), default='')
    product_interest: Mapped[str] = mapped_column(String(150), default='')
    transcript: Mapped[str] = mapped_column(Text, default='')
    status: Mapped[str] = mapped_column(String(50), default='New')
    confidence: Mapped[int] = mapped_column(Integer, default=0)
    intent: Mapped[str] = mapped_column(String(100), default='General Inquiry')
    sentiment: Mapped[str] = mapped_column(String(50), default='Neutral')
    priority: Mapped[str] = mapped_column(String(50), default='Normal')
    lead_score: Mapped[int] = mapped_column(Integer, default=50)
    ai_summary: Mapped[str] = mapped_column(Text, default='')
    next_action: Mapped[str] = mapped_column(Text, default='')
    assigned_user_external_id: Mapped[str | None] = mapped_column(
        String(36), nullable=True, index=True
    )
    version: Mapped[int] = mapped_column(Integer, default=1)
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)


class TrackingEvent(Base, TimestampMixin):
    __tablename__ = 'tracking_events'

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    external_id: Mapped[str] = mapped_column(
        String(36), unique=True, default=_uuid, index=True
    )
    company_id: Mapped[int | None] = mapped_column(Integer, nullable=True, index=True)
    employee_external_id: Mapped[str] = mapped_column(String(36), index=True)
    lead_external_id: Mapped[str | None] = mapped_column(String(36), nullable=True)
    event_type: Mapped[str] = mapped_column(String(50), default='location_ping')
    latitude: Mapped[str] = mapped_column(String(40))
    longitude: Mapped[str] = mapped_column(String(40))
    accuracy: Mapped[str] = mapped_column(String(40), default='0')
    notes: Mapped[str] = mapped_column(Text, default='')
    proof_image_url: Mapped[str] = mapped_column(Text, default='')
    version: Mapped[int] = mapped_column(Integer, default=1)


class FieldReport(Base, TimestampMixin):
    __tablename__ = 'field_reports'

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    external_id: Mapped[str] = mapped_column(
        String(36), unique=True, default=_uuid, index=True
    )
    company_id: Mapped[int | None] = mapped_column(Integer, nullable=True, index=True)
    employee_external_id: Mapped[str] = mapped_column(String(36), index=True)
    lead_external_id: Mapped[str | None] = mapped_column(String(36), nullable=True)
    outcome: Mapped[str] = mapped_column(String(100))
    voice_audio_url: Mapped[str] = mapped_column(Text, default='')
    voice_transcript: Mapped[str] = mapped_column(Text, default='')
    text_notes: Mapped[str] = mapped_column(Text, default='')
    admin_comment: Mapped[str] = mapped_column(Text, default='')
    suggested_lead_status: Mapped[str] = mapped_column(String(100), default='')
    version: Mapped[int] = mapped_column(Integer, default=1)


class UploadedMedia(Base, TimestampMixin):
    __tablename__ = 'uploaded_media'

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    external_id: Mapped[str] = mapped_column(
        String(36), unique=True, default=_uuid, index=True
    )
    company_id: Mapped[int | None] = mapped_column(Integer, nullable=True, index=True)
    uploader_user_id: Mapped[int | None] = mapped_column(
        ForeignKey('users.id'), nullable=True, index=True
    )
    related_type: Mapped[str] = mapped_column(String(50), default='general', index=True)
    related_external_id: Mapped[str] = mapped_column(String(120), default='', index=True)
    category: Mapped[str] = mapped_column(String(50), default='general', index=True)
    original_filename: Mapped[str] = mapped_column(String(255), default='')
    stored_filename: Mapped[str] = mapped_column(String(255), default='')
    relative_path: Mapped[str] = mapped_column(Text, default='')
    public_url: Mapped[str] = mapped_column(Text, default='')
    mime_type: Mapped[str] = mapped_column(String(150), default='application/octet-stream')
    file_size_bytes: Mapped[int] = mapped_column(Integer, default=0)

    uploader: Mapped[User | None] = relationship(back_populates='uploaded_media')


class AuditLog(Base):
    __tablename__ = 'audit_logs'

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    company_id: Mapped[int | None] = mapped_column(Integer, nullable=True, index=True)
    actor_user_id: Mapped[int | None] = mapped_column(
        ForeignKey('users.id'), nullable=True, index=True
    )
    actor_role: Mapped[str] = mapped_column(String(30), default='System')
    action: Mapped[str] = mapped_column(String(100), index=True)
    entity_type: Mapped[str] = mapped_column(String(50), index=True)
    # Wide enough for composite keys such as '<employee_uuid>:<lead_id>'.
    # At String(36) that overflowed and Postgres raised, returning a 500.
    entity_external_id: Mapped[str] = mapped_column(String(120), default='')
    details: Mapped[str] = mapped_column(Text, default='')
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    actor: Mapped[User | None] = relationship(back_populates='audit_logs')


class PasswordResetToken(Base):
    __tablename__ = 'password_reset_tokens'

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey('users.id'), index=True)
    token: Mapped[str] = mapped_column(String(64), unique=True, index=True)
    expires_at: Mapped[datetime] = mapped_column(DateTime)
    used_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    user: Mapped[User] = relationship(back_populates='password_reset_tokens')
