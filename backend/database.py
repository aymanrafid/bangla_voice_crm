from sqlalchemy import create_engine
from sqlalchemy.orm import declarative_base, sessionmaker

from .config import settings


connect_args = {"check_same_thread": False} if settings.is_sqlite else {}
engine_kwargs = {
    "future": True,
    "connect_args": connect_args,
    # Managed Postgres drops idle connections. Without this the pool hands the
    # next request a dead socket, which stalls instead of failing fast.
    "pool_pre_ping": True,
}
if not settings.is_sqlite:
    # Recycle below the provider's idle-connection window so a stale socket is
    # never reused in the first place.
    engine_kwargs["pool_recycle"] = 280
engine = create_engine(settings.normalized_database_url, **engine_kwargs)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine, future=True)
Base = declarative_base()


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
