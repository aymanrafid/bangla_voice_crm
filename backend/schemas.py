from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class CompanyRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    external_id: str
    name: str
    slug: str
    status: str
    created_at: datetime
    updated_at: datetime


class CompanyCreateRequest(BaseModel):
    name: str
    slug: str | None = None
    admin_username: str
    admin_password: str = Field(min_length=8)
    admin_full_name: str


class UserBase(BaseModel):
    username: str
    full_name: str
    role: str = 'Employee'
    is_active: bool = True


class UserCreate(UserBase):
    password: str = Field(min_length=8)
    company_external_id: str | None = None


class UserRead(UserBase):
    model_config = ConfigDict(from_attributes=True)

    external_id: str
    company_external_id: str = ''
    company_name: str = ''
    company_slug: str = ''
    created_at: datetime


class CompanyProvisionResponse(BaseModel):
    company: CompanyRead
    admin_user: UserRead


class LoginRequest(BaseModel):
    username: str
    password: str
    company_slug: str | None = None


class LoginResponse(BaseModel):
    access_token: str
    token_type: str = 'bearer'
    user: UserRead


class PasswordResetRequest(BaseModel):
    username: str


class PasswordResetConfirm(BaseModel):
    token: str
    new_password: str = Field(min_length=8)


class LeadCreate(BaseModel):
    external_id: str | None = None
    lead_type: str = 'Sales Lead'
    name: str = ''
    phone: str = ''
    address: str = ''
    location: str = ''
    product_interest: str = ''
    transcript: str = ''
    status: str = 'New'
    confidence: int = 0
    intent: str = 'General Inquiry'
    sentiment: str = 'Neutral'
    priority: str = 'Normal'
    lead_score: int = 50
    ai_summary: str = ''
    next_action: str = ''
    assigned_user_external_id: str | None = None
    client_updated_at: datetime | None = None
    version: int = 1


class LeadUpdate(LeadCreate):
    pass


class LeadRead(LeadCreate):
    model_config = ConfigDict(from_attributes=True)

    external_id: str
    created_at: datetime
    updated_at: datetime
    deleted_at: datetime | None = None


class TrackingEventCreate(BaseModel):
    external_id: str | None = None
    employee_external_id: str
    lead_external_id: str | None = None
    event_type: str = 'location_ping'
    latitude: str
    longitude: str
    accuracy: str = '0'
    notes: str = ''
    proof_image_url: str = ''
    version: int = 1


class TrackingEventRead(TrackingEventCreate):
    model_config = ConfigDict(from_attributes=True)

    external_id: str
    created_at: datetime
    updated_at: datetime


class FieldReportCreate(BaseModel):
    external_id: str | None = None
    employee_external_id: str
    lead_external_id: str | None = None
    outcome: str
    voice_audio_url: str = ''
    voice_transcript: str = ''
    text_notes: str = ''
    admin_comment: str = ''
    suggested_lead_status: str = ''
    version: int = 1


class FieldReportRead(FieldReportCreate):
    model_config = ConfigDict(from_attributes=True)

    external_id: str
    created_at: datetime
    updated_at: datetime
    image_urls: list[str] = []


class UploadedMediaRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    external_id: str
    related_type: str
    related_external_id: str
    category: str
    original_filename: str
    stored_filename: str
    relative_path: str
    public_url: str
    mime_type: str
    file_size_bytes: int
    created_at: datetime
    updated_at: datetime


class AuditLogRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    actor_role: str
    action: str
    entity_type: str
    entity_external_id: str
    details: str
    created_at: datetime


class SyncPayload(BaseModel):
    leads: list[LeadRead]
    tracking_events: list[TrackingEventRead]
    reports: list[FieldReportRead]
    server_time: datetime
