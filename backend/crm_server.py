from pathlib import Path
import re
import shutil
from datetime import datetime, timedelta
import uuid

from fastapi import Depends, FastAPI, File, Form, HTTPException, Query, Request, UploadFile, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from sqlalchemy import inspect, text
from sqlalchemy.orm import Session

from .config import settings
from .database import Base, SessionLocal, engine, get_db
from .deps import get_current_user, require_roles
from .models import AuditLog, Company, FieldReport, Lead, PasswordResetToken, TrackingEvent, UploadedMedia, User
from .schemas import AuditLogRead, CompanyCreateRequest, CompanyProvisionResponse, CompanyRead, FieldReportCreate, FieldReportRead, LeadCreate, LeadRead, LeadUpdate, LoginRequest, LoginResponse, PasswordResetConfirm, PasswordResetRequest, SyncPayload, TrackingEventCreate, TrackingEventRead, UploadedMediaRead, UserCreate, UserRead
from .security import create_access_token, create_reset_token, hash_password, verify_password

app = FastAPI(title=settings.app_name)
app.add_middleware(CORSMiddleware, allow_origins=settings.cors_origins, allow_credentials=settings.cors_allow_credentials and settings.cors_origins != ['*'], allow_methods=['*'], allow_headers=['*'])
UPLOAD_ROOT = Path(__file__).resolve().parent / 'uploads'
UPLOAD_ROOT.mkdir(parents=True, exist_ok=True)
app.mount('/media-files', StaticFiles(directory=str(UPLOAD_ROOT)), name='media-files')
TENANT_TABLES = ['users', 'leads', 'tracking_events', 'field_reports', 'uploaded_media', 'audit_logs']


def _slugify(value: str) -> str:
    slug = re.sub(r'[^a-z0-9]+', '-', value.strip().lower()).strip('-')
    return slug or 'company'


def _is_super_admin(user: User | None) -> bool:
    return user is not None and user.role == 'SuperAdmin'


def _log_action(db: Session, *, action: str, entity_type: str, entity_external_id: str, details: str, actor: User | None, company_id: int | None = None):
    db.add(AuditLog(company_id=company_id if company_id is not None else (actor.company_id if actor else None), actor_user_id=actor.id if actor else None, actor_role=actor.role if actor else 'System', action=action, entity_type=entity_type, entity_external_id=entity_external_id, details=details))


def _scope_company(query, model, current_user: User):
    return query if _is_super_admin(current_user) else query.filter(model.company_id == current_user.company_id)


def _ensure_same_company_record(record_company_id: int | None, current_user: User, detail: str = 'Resource not found.'):
    if not _is_super_admin(current_user) and record_company_id != current_user.company_id:
        raise HTTPException(status_code=404, detail=detail)


def _get_company_by_external_id(db: Session, external_id: str) -> Company | None:
    return db.query(Company).filter(Company.external_id == external_id).first()


def _get_scoped_user_by_external_id(db: Session, current_user: User, external_id: str) -> User:
    user = db.query(User).filter(User.external_id == external_id).first()
    if user is None or (not _is_super_admin(current_user) and user.company_id != current_user.company_id):
        raise HTTPException(status_code=404, detail='User not found.')
    return user


def _serialize_lead(db: Session, lead: Lead) -> dict:
    assigned_user_name = ''
    if lead.assigned_user_external_id:
        assigned_user = db.query(User).filter(User.external_id == lead.assigned_user_external_id).first()
        if assigned_user is not None:
            assigned_user_name = assigned_user.full_name
    return {
        'external_id': lead.external_id,
        'lead_type': lead.lead_type,
        'name': lead.name,
        'phone': lead.phone,
        'address': lead.address,
        'location': lead.location,
        'product_interest': lead.product_interest,
        'transcript': lead.transcript,
        'status': lead.status,
        'confidence': lead.confidence,
        'intent': lead.intent,
        'sentiment': lead.sentiment,
        'priority': lead.priority,
        'lead_score': lead.lead_score,
        'ai_summary': lead.ai_summary,
        'next_action': lead.next_action,
        'assigned_user_external_id': lead.assigned_user_external_id,
        'assigned_user_name': assigned_user_name,
        'client_updated_at': None,
        'version': lead.version,
        'created_at': lead.created_at,
        'updated_at': lead.updated_at,
        'deleted_at': lead.deleted_at,
    }


def _resolve_user_company(db: Session, current_user: User, company_external_id: str | None) -> Company:
    if not _is_super_admin(current_user):
        if current_user.company is None:
            raise HTTPException(status_code=400, detail='Current user is not linked to a company.')
        return current_user.company
    if company_external_id:
        company = _get_company_by_external_id(db, company_external_id)
        if company is None:
            raise HTTPException(status_code=404, detail='Company not found.')
        return company
    if current_user.company is None:
        raise HTTPException(status_code=400, detail='Super admin does not have a default company.')
    return current_user.company


def _get_or_create_default_company(db: Session) -> Company:
    slug = _slugify(settings.bootstrap_company_slug or settings.bootstrap_company_name)
    company = db.query(Company).filter(Company.slug == slug).first()
    if company:
        return company
    company = Company(name=settings.bootstrap_company_name.strip() or 'Platform Default Company', slug=slug, status='active')
    db.add(company)
    db.commit()
    db.refresh(company)
    return company


def _ensure_multi_tenant_schema() -> None:
    with engine.begin() as connection:
        tables = set(inspect(connection).get_table_names())
        for table_name in TENANT_TABLES:
            if table_name not in tables:
                continue
            columns = {column['name'] for column in inspect(connection).get_columns(table_name)}
            if 'company_id' not in columns:
                connection.execute(text(f'ALTER TABLE {table_name} ADD COLUMN company_id INTEGER'))
    with SessionLocal() as db:
        company = _get_or_create_default_company(db)
        for table_name in TENANT_TABLES:
            db.execute(text(f'UPDATE {table_name} SET company_id = :company_id WHERE company_id IS NULL OR company_id = 0'), {'company_id': company.id})
        db.commit()


def _bootstrap_admin() -> None:
    if not settings.bootstrap_admin_username or not settings.bootstrap_admin_password:
        return
    with SessionLocal() as db:
        company = _get_or_create_default_company(db)
        existing = db.query(User).filter(User.username == settings.bootstrap_admin_username).first()
        if existing:
            changed = False
            if existing.company_id != company.id:
                existing.company_id = company.id
                changed = True
            if existing.role != settings.bootstrap_admin_role:
                existing.role = settings.bootstrap_admin_role
                changed = True
            if existing.full_name != settings.bootstrap_admin_full_name:
                existing.full_name = settings.bootstrap_admin_full_name
                changed = True
            if changed:
                db.commit()
            return
        db.add(User(username=settings.bootstrap_admin_username, company_id=company.id, full_name=settings.bootstrap_admin_full_name, password_hash=hash_password(settings.bootstrap_admin_password), role=settings.bootstrap_admin_role, is_active=True))
        db.commit()


def _get_report_image_urls(db: Session, report: FieldReport) -> list[str]:
    records = db.query(UploadedMedia).filter(UploadedMedia.company_id == report.company_id).filter(UploadedMedia.related_type == 'field_report').filter(UploadedMedia.related_external_id == report.external_id).filter(UploadedMedia.category == 'images').order_by(UploadedMedia.created_at.asc()).all()
    return [record.public_url for record in records if record.public_url]


def _serialize_report(db: Session, report: FieldReport) -> dict:
    return {'external_id': report.external_id, 'employee_external_id': report.employee_external_id, 'lead_external_id': report.lead_external_id, 'outcome': report.outcome, 'voice_audio_url': report.voice_audio_url, 'voice_transcript': report.voice_transcript, 'text_notes': report.text_notes, 'admin_comment': report.admin_comment, 'suggested_lead_status': report.suggested_lead_status, 'version': report.version, 'created_at': report.created_at, 'updated_at': report.updated_at, 'image_urls': _get_report_image_urls(db, report)}


@app.on_event('startup')
def _startup():
    Base.metadata.create_all(bind=engine)
    _ensure_multi_tenant_schema()
    _bootstrap_admin()


@app.get('/')
def root():
    return {'service': settings.app_name, 'environment': settings.environment, 'public_base_url': settings.public_base_url, 'multi_tenant': True, 'status': 'ok'}


@app.get('/companies', response_model=list[CompanyRead])
def list_companies(db: Session = Depends(get_db), current_user: User = Depends(require_roles('Admin'))):
    if not _is_super_admin(current_user):
        raise HTTPException(status_code=403, detail='Only super admin can view all companies.')
    return db.query(Company).order_by(Company.name.asc()).all()


@app.post('/companies', response_model=CompanyProvisionResponse)
def create_company(payload: CompanyCreateRequest, db: Session = Depends(get_db), current_user: User = Depends(require_roles('Admin'))):
    if not _is_super_admin(current_user):
        raise HTTPException(status_code=403, detail='Only super admin can create companies.')
    slug = _slugify(payload.slug or payload.name)
    if db.query(Company).filter(Company.slug == slug).first() is not None:
        raise HTTPException(status_code=409, detail='Company slug already exists.')
    if db.query(Company).filter(Company.name == payload.name.strip()).first() is not None:
        raise HTTPException(status_code=409, detail='Company name already exists.')
    if db.query(User).filter(User.username == payload.admin_username.strip()).first() is not None:
        raise HTTPException(status_code=409, detail='Admin username already exists.')
    company = Company(name=payload.name.strip(), slug=slug, status='active')
    db.add(company)
    db.flush()
    admin_user = User(username=payload.admin_username.strip(), company_id=company.id, full_name=payload.admin_full_name.strip(), password_hash=hash_password(payload.admin_password), role='Admin', is_active=True)
    db.add(admin_user)
    db.flush()
    _log_action(db, action='create_company', entity_type='company', entity_external_id=company.external_id, details=f'Created company {company.name} with admin {admin_user.username}.', actor=current_user, company_id=company.id)
    db.commit()
    db.refresh(company)
    db.refresh(admin_user)
    return CompanyProvisionResponse(company=company, admin_user=admin_user)


@app.post('/media/upload', response_model=UploadedMediaRead)
def upload_media(request: Request, file: UploadFile = File(...), category: str = Form('general'), related_type: str = Form('general'), related_external_id: str = Form(''), db: Session = Depends(get_db), current_user: User = Depends(require_roles('Admin', 'Manager', 'Employee'))):
    safe_category = ''.join(ch for ch in category if ch.isalnum() or ch in {'-', '_'}) or 'general'
    safe_related_type = ''.join(ch for ch in related_type if ch.isalnum() or ch in {'-', '_'}) or 'general'
    category_dir = UPLOAD_ROOT / safe_category
    category_dir.mkdir(parents=True, exist_ok=True)
    original_name = Path(file.filename or 'upload.bin').name
    target_name = f'{uuid.uuid4().hex}_{original_name}'
    target_path = category_dir / target_name
    with target_path.open('wb') as buffer:
        shutil.copyfileobj(file.file, buffer)
    relative_url = f'/media-files/{safe_category}/{target_name}'
    public_url = f"{str(request.base_url).rstrip('/')}{relative_url}"
    media = UploadedMedia(company_id=current_user.company_id, uploader_user_id=current_user.id, related_type=safe_related_type, related_external_id=related_external_id.strip(), category=safe_category, original_filename=original_name, stored_filename=target_name, relative_path=relative_url, public_url=public_url, mime_type=file.content_type or 'application/octet-stream', file_size_bytes=target_path.stat().st_size)
    db.add(media)
    db.flush()
    _log_action(db, action='upload_media', entity_type='uploaded_media', entity_external_id=media.external_id, details=f"Uploaded {safe_category} for {safe_related_type} {related_external_id.strip() or 'unlinked'}.", actor=current_user)
    db.commit()
    db.refresh(media)
    return media


@app.get('/media', response_model=list[UploadedMediaRead])
def list_uploaded_media(related_type: str | None = None, related_external_id: str | None = None, category: str | None = None, limit: int = Query(default=200, ge=1, le=500), db: Session = Depends(get_db), current_user: User = Depends(require_roles('Admin', 'Manager', 'Employee'))):
    query = _scope_company(db.query(UploadedMedia), UploadedMedia, current_user)
    if related_type:
        query = query.filter(UploadedMedia.related_type == related_type)
    if related_external_id:
        query = query.filter(UploadedMedia.related_external_id == related_external_id)
    if category:
        query = query.filter(UploadedMedia.category == category)
    return query.order_by(UploadedMedia.created_at.desc()).limit(limit).all()


@app.get('/health')
def health(db: Session = Depends(get_db)):
    db.execute(text('SELECT 1'))
    return {'status': 'ok', 'database': 'connected', 'time': datetime.utcnow().isoformat(), 'environment': settings.environment, 'multi_tenant': True}


@app.post('/auth/login', response_model=LoginResponse)
def login(payload: LoginRequest, db: Session = Depends(get_db)):
    query = db.query(User)
    if payload.company_slug:
        query = query.join(Company).filter(Company.slug == _slugify(payload.company_slug))
    user = query.filter(User.username == payload.username.strip()).first()
    if user is None or not user.is_active:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail='Invalid username or inactive account.')
    if not verify_password(payload.password, user.password_hash):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail='Invalid password.')
    token = create_access_token(subject=user.external_id, role=user.role, company_external_id=user.company_external_id, company_slug=user.company_slug)
    _log_action(db, action='login', entity_type='user', entity_external_id=user.external_id, details='User logged in.', actor=user)
    db.commit()
    return LoginResponse(access_token=token, user=user)


@app.get('/auth/me', response_model=UserRead)
def auth_me(current_user: User = Depends(get_current_user)):
    return current_user


@app.post('/auth/users', response_model=UserRead)
def create_user(payload: UserCreate, db: Session = Depends(get_db), current_user: User = Depends(require_roles('Admin'))):
    existing = db.query(User).filter(User.username == payload.username.strip()).first()
    if existing:
        raise HTTPException(status_code=409, detail='Username already exists.')
    company = _resolve_user_company(db, current_user, payload.company_external_id)
    user = User(username=payload.username.strip(), company_id=company.id, full_name=payload.full_name.strip(), password_hash=hash_password(payload.password), role=payload.role, is_active=payload.is_active)
    db.add(user)
    db.flush()
    _log_action(db, action='create_user', entity_type='user', entity_external_id=user.external_id, details=f'Created role={user.role} in {company.name}.', actor=current_user, company_id=company.id)
    db.commit()
    db.refresh(user)
    return user


@app.get('/users', response_model=list[UserRead])
def list_users(db: Session = Depends(get_db), current_user: User = Depends(require_roles('Admin', 'Manager'))):
    return _scope_company(db.query(User), User, current_user).order_by(User.full_name.asc()).all()


@app.post('/auth/password-reset/request')
def request_password_reset(payload: PasswordResetRequest, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.username == payload.username.strip()).first()
    if user is None:
        return {'message': 'If the user exists, a reset token has been issued.'}
    token_value = create_reset_token()
    db.add(PasswordResetToken(user_id=user.id, token=token_value, expires_at=datetime.utcnow() + timedelta(minutes=30)))
    _log_action(db, action='request_password_reset', entity_type='user', entity_external_id=user.external_id, details='Password reset requested.', actor=None, company_id=user.company_id)
    db.commit()
    response = {'message': 'Password reset token created.'}
    if settings.effective_expose_reset_tokens:
        response['reset_token'] = token_value
    return response


@app.post('/auth/password-reset/confirm')
def confirm_password_reset(payload: PasswordResetConfirm, db: Session = Depends(get_db)):
    record = db.query(PasswordResetToken).filter(PasswordResetToken.token == payload.token).first()
    if record is None or record.used_at is not None or record.expires_at < datetime.utcnow():
        raise HTTPException(status_code=400, detail='Reset token is invalid or expired.')
    user = db.query(User).filter(User.id == record.user_id).first()
    if user is None:
        raise HTTPException(status_code=404, detail='User not found.')
    user.password_hash = hash_password(payload.new_password)
    record.used_at = datetime.utcnow()
    _log_action(db, action='confirm_password_reset', entity_type='user', entity_external_id=user.external_id, details='Password reset completed.', actor=None, company_id=user.company_id)
    db.commit()
    return {'message': 'Password updated successfully.'}


@app.post('/leads', response_model=LeadRead)
def create_lead(payload: LeadCreate, db: Session = Depends(get_db), current_user: User = Depends(require_roles('Admin', 'Manager', 'Employee'))):
    lead_company_id = current_user.company_id
    if payload.assigned_user_external_id:
        assigned_user = _get_scoped_user_by_external_id(db, current_user, payload.assigned_user_external_id)
        if assigned_user.role != 'Employee':
            raise HTTPException(status_code=400, detail='Assigned user must be an employee.')
        lead_company_id = assigned_user.company_id
    lead = Lead(external_id=payload.external_id or str(uuid.uuid4()), company_id=lead_company_id, lead_type=payload.lead_type, name=payload.name, phone=payload.phone, address=payload.address, location=payload.location, product_interest=payload.product_interest, transcript=payload.transcript, status=payload.status, confidence=payload.confidence, intent=payload.intent, sentiment=payload.sentiment, priority=payload.priority, lead_score=payload.lead_score, ai_summary=payload.ai_summary, next_action=payload.next_action, assigned_user_external_id=payload.assigned_user_external_id, version=max(1, payload.version))
    db.add(lead)
    db.flush()
    _log_action(db, action='create_lead', entity_type='lead', entity_external_id=lead.external_id, details=f'Lead created for {lead.name or lead.phone}.', actor=current_user, company_id=lead.company_id)
    db.commit()
    db.refresh(lead)
    return _serialize_lead(db, lead)


@app.get('/leads', response_model=list[LeadRead])
def list_leads(assigned_user_external_id: str | None = None, db: Session = Depends(get_db), current_user: User = Depends(require_roles('Admin', 'Manager', 'Employee'))):
    query = _scope_company(db.query(Lead), Lead, current_user).filter(Lead.deleted_at.is_(None))
    if current_user.role == 'Employee':
        if assigned_user_external_id:
            if assigned_user_external_id != current_user.external_id:
                raise HTTPException(status_code=403, detail='Employees can only request their own assigned leads.')
            query = query.filter(Lead.assigned_user_external_id == current_user.external_id)
        else:
            query = query.filter((Lead.assigned_user_external_id == current_user.external_id) | (Lead.assigned_user_external_id.is_(None)))
    elif assigned_user_external_id:
        _get_scoped_user_by_external_id(db, current_user, assigned_user_external_id)
        query = query.filter(Lead.assigned_user_external_id == assigned_user_external_id)
    leads = query.order_by(Lead.updated_at.desc()).all()
    return [_serialize_lead(db, lead) for lead in leads]


@app.put('/leads/{external_id}', response_model=LeadRead)
def update_lead(external_id: str, payload: LeadUpdate, db: Session = Depends(get_db), current_user: User = Depends(require_roles('Admin', 'Manager', 'Employee'))):
    lead = db.query(Lead).filter(Lead.external_id == external_id).first()
    if lead is None:
        raise HTTPException(status_code=404, detail='Lead not found.')
    _ensure_same_company_record(lead.company_id, current_user, 'Lead not found.')
    if payload.version < lead.version:
        raise HTTPException(status_code=409, detail='Sync conflict detected. Fetch latest server version first.')
    if payload.assigned_user_external_id:
        assigned_user = _get_scoped_user_by_external_id(db, current_user, payload.assigned_user_external_id)
        if assigned_user.company_id != lead.company_id:
            raise HTTPException(status_code=400, detail='Assigned employee belongs to another company.')
        if assigned_user.role != 'Employee':
            raise HTTPException(status_code=400, detail='Assigned user must be an employee.')
    for field_name, value in payload.model_dump(exclude={'external_id'}).items():
        if field_name == 'client_updated_at':
            continue
        setattr(lead, field_name, value)
    lead.version += 1
    _log_action(db, action='update_lead', entity_type='lead', entity_external_id=lead.external_id, details=f'Lead updated to version {lead.version}.', actor=current_user, company_id=lead.company_id)
    db.commit()
    db.refresh(lead)
    return _serialize_lead(db, lead)


@app.post('/field-tracking', response_model=TrackingEventRead)
def create_tracking_event(payload: TrackingEventCreate, db: Session = Depends(get_db), current_user: User = Depends(require_roles('Admin', 'Manager', 'Employee'))):
    if current_user.role != 'Employee':
        raise HTTPException(status_code=403, detail='Only employee accounts can publish tracking events.')
    if payload.employee_external_id != current_user.external_id:
        raise HTTPException(status_code=403, detail='Tracking event employee identity does not match the current session.')
    event = TrackingEvent(external_id=payload.external_id or str(uuid.uuid4()), company_id=current_user.company_id, employee_external_id=payload.employee_external_id, lead_external_id=payload.lead_external_id, event_type=payload.event_type, latitude=payload.latitude, longitude=payload.longitude, accuracy=payload.accuracy, notes=payload.notes, proof_image_url=payload.proof_image_url, version=max(1, payload.version))
    db.add(event)
    db.flush()
    _log_action(db, action='create_tracking_event', entity_type='tracking_event', entity_external_id=event.external_id, details=f'Tracking event {event.event_type}.', actor=current_user, company_id=event.company_id)
    db.commit()
    db.refresh(event)
    return event


@app.get('/field-tracking', response_model=list[TrackingEventRead])
def list_tracking_events(employee_external_id: str | None = None, db: Session = Depends(get_db), current_user: User = Depends(require_roles('Admin', 'Manager', 'Employee'))):
    query = _scope_company(db.query(TrackingEvent), TrackingEvent, current_user)
    employee_ids = _scope_company(db.query(User.external_id), User, current_user).filter(User.role == 'Employee')
    query = query.filter(TrackingEvent.employee_external_id.in_(employee_ids))
    if current_user.role == 'Employee':
        query = query.filter(TrackingEvent.employee_external_id == current_user.external_id)
    elif employee_external_id:
        _get_scoped_user_by_external_id(db, current_user, employee_external_id)
        query = query.filter(TrackingEvent.employee_external_id == employee_external_id)
    return query.order_by(TrackingEvent.created_at.desc()).all()


@app.delete('/field-tracking/history/{employee_external_id}/{lead_external_id}')
def delete_tracking_history(employee_external_id: str, lead_external_id: str, db: Session = Depends(get_db), current_user: User = Depends(require_roles('Admin'))):
    user = _get_scoped_user_by_external_id(db, current_user, employee_external_id)
    query = _scope_company(db.query(TrackingEvent), TrackingEvent, current_user).filter(TrackingEvent.employee_external_id == user.external_id, TrackingEvent.lead_external_id == lead_external_id)
    deleted_count = query.count()
    if deleted_count == 0:
        raise HTTPException(status_code=404, detail='Tracking history not found.')
    query.delete(synchronize_session=False)
    _log_action(db, action='delete_tracking_history', entity_type='tracking_event', entity_external_id=f'{employee_external_id}:{lead_external_id}', details=f'Deleted {deleted_count} tracking events.', actor=current_user, company_id=user.company_id)
    db.commit()
    return {'message': 'Tracking history deleted successfully.'}


@app.post('/reports', response_model=FieldReportRead)
def create_report(payload: FieldReportCreate, db: Session = Depends(get_db), current_user: User = Depends(require_roles('Admin', 'Manager', 'Employee'))):
    employee_user = _get_scoped_user_by_external_id(db, current_user, payload.employee_external_id)
    if current_user.role == 'Employee' and employee_user.external_id != current_user.external_id:
        raise HTTPException(status_code=403, detail='Employees can only submit their own reports.')
    report = FieldReport(external_id=payload.external_id or str(uuid.uuid4()), company_id=employee_user.company_id, employee_external_id=payload.employee_external_id, lead_external_id=payload.lead_external_id, outcome=payload.outcome, voice_audio_url=payload.voice_audio_url, voice_transcript=payload.voice_transcript, text_notes=payload.text_notes, admin_comment=payload.admin_comment, suggested_lead_status=payload.suggested_lead_status, version=max(1, payload.version))
    db.add(report)
    db.flush()
    _log_action(db, action='create_report', entity_type='field_report', entity_external_id=report.external_id, details=f'Report submitted with outcome={report.outcome}.', actor=current_user, company_id=report.company_id)
    db.commit()
    db.refresh(report)
    return _serialize_report(db, report)


@app.get('/reports', response_model=list[FieldReportRead])
def list_reports(employee_external_id: str | None = None, db: Session = Depends(get_db), current_user: User = Depends(require_roles('Admin', 'Manager', 'Employee'))):
    query = _scope_company(db.query(FieldReport), FieldReport, current_user)
    if current_user.role == 'Employee':
        query = query.filter(FieldReport.employee_external_id == current_user.external_id)
    elif employee_external_id:
        _get_scoped_user_by_external_id(db, current_user, employee_external_id)
        query = query.filter(FieldReport.employee_external_id == employee_external_id)
    reports = query.order_by(FieldReport.created_at.desc()).all()
    return [_serialize_report(db, report) for report in reports]


@app.get('/audit-logs', response_model=list[AuditLogRead])
def list_audit_logs(limit: int = Query(default=100, ge=1, le=500), db: Session = Depends(get_db), current_user: User = Depends(require_roles('Admin', 'Manager'))):
    return _scope_company(db.query(AuditLog), AuditLog, current_user).order_by(AuditLog.created_at.desc()).limit(limit).all()


@app.get('/sync/changes', response_model=SyncPayload)
def sync_changes(since: datetime | None = None, db: Session = Depends(get_db), current_user: User = Depends(require_roles('Admin', 'Manager', 'Employee'))):
    since_dt = since or datetime(1970, 1, 1)
    leads = _scope_company(db.query(Lead), Lead, current_user).filter(Lead.updated_at >= since_dt).all()
    tracking_events = _scope_company(db.query(TrackingEvent), TrackingEvent, current_user).filter(TrackingEvent.updated_at >= since_dt).all()
    reports = _scope_company(db.query(FieldReport), FieldReport, current_user).filter(FieldReport.updated_at >= since_dt).all()
    return SyncPayload(leads=leads, tracking_events=tracking_events, reports=[FieldReportRead.model_validate(_serialize_report(db, report)) for report in reports], server_time=datetime.utcnow())


@app.delete('/leads/{external_id}')
def delete_lead(external_id: str, db: Session = Depends(get_db), current_user: User = Depends(require_roles('Admin', 'Manager'))):
    lead = db.query(Lead).filter(Lead.external_id == external_id).first()
    if lead is None:
        raise HTTPException(status_code=404, detail='Lead not found.')
    _ensure_same_company_record(lead.company_id, current_user, 'Lead not found.')
    lead.deleted_at = datetime.utcnow()
    _log_action(db, action='delete_lead', entity_type='lead', entity_external_id=lead.external_id, details='Lead soft-deleted.', actor=current_user, company_id=lead.company_id)
    db.commit()
    return {'message': 'Lead deleted successfully.'}


@app.put('/reports/{external_id}/review')
def update_report_review(external_id: str, payload: dict, db: Session = Depends(get_db), current_user: User = Depends(require_roles('Admin', 'Manager'))):
    report = db.query(FieldReport).filter(FieldReport.external_id == external_id).first()
    if report is None:
        raise HTTPException(status_code=404, detail='Report not found.')
    _ensure_same_company_record(report.company_id, current_user, 'Report not found.')
    report.admin_comment = payload.get('admin_comment', report.admin_comment)
    report.suggested_lead_status = payload.get('suggested_lead_status', report.suggested_lead_status)
    if report.lead_external_id and report.suggested_lead_status:
        lead = db.query(Lead).filter(Lead.external_id == report.lead_external_id).filter(Lead.company_id == report.company_id).first()
        if lead is not None:
            lead.status = report.suggested_lead_status
            lead.version += 1
    _log_action(db, action='review_report', entity_type='field_report', entity_external_id=report.external_id, details='Admin review updated.', actor=current_user, company_id=report.company_id)
    db.commit()
    return {'message': 'Report review updated successfully.'}
