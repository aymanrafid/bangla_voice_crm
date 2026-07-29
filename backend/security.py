import secrets
from datetime import datetime, timedelta

from jose import jwt
from passlib.context import CryptContext

from .config import settings


pwd_context = CryptContext(
    schemes=['pbkdf2_sha256'],
    deprecated='auto',
)


def hash_password(password: str) -> str:
    return pwd_context.hash(password)


def verify_password(plain_password: str, password_hash: str) -> bool:
    return pwd_context.verify(plain_password, password_hash)


def create_access_token(
    *,
    subject: str,
    role: str,
    company_external_id: str = '',
    company_slug: str = '',
) -> str:
    expire = datetime.utcnow() + timedelta(
        minutes=settings.access_token_expiry_minutes
    )
    payload = {
        'sub': subject,
        'role': role,
        'company_external_id': company_external_id,
        'company_slug': company_slug,
        'exp': expire,
        'type': 'access',
    }
    return jwt.encode(payload, settings.jwt_secret, algorithm=settings.jwt_algorithm)


def decode_token(token: str) -> dict:
    return jwt.decode(
        token,
        settings.jwt_secret,
        algorithms=[settings.jwt_algorithm],
    )


def create_reset_token() -> str:
    return secrets.token_urlsafe(32)
