import os


class Settings:
    app_name: str = os.getenv("CRM_APP_NAME", "Bangla Voice CRM API")
    environment: str = os.getenv("CRM_ENV", "development")
    database_url: str = os.getenv("CRM_DATABASE_URL", "sqlite:///./crm_prod.db")
    jwt_secret: str = os.getenv("CRM_JWT_SECRET", "change-this-in-production")
    jwt_algorithm: str = os.getenv("CRM_JWT_ALGORITHM", "HS256")
    access_token_expiry_minutes: int = int(
        os.getenv("CRM_ACCESS_TOKEN_EXPIRE_MINUTES", "720")
    )
    bootstrap_company_name: str = os.getenv(
        "CRM_BOOTSTRAP_COMPANY_NAME", "Platform Default Company"
    )
    bootstrap_company_slug: str = os.getenv(
        "CRM_BOOTSTRAP_COMPANY_SLUG", "platform-default"
    )
    bootstrap_admin_username: str = os.getenv("CRM_BOOTSTRAP_ADMIN_USERNAME", "")
    bootstrap_admin_password: str = os.getenv("CRM_BOOTSTRAP_ADMIN_PASSWORD", "")
    bootstrap_admin_full_name: str = os.getenv(
        "CRM_BOOTSTRAP_ADMIN_FULL_NAME", "System Admin"
    )
    bootstrap_admin_role: str = os.getenv(
        "CRM_BOOTSTRAP_ADMIN_ROLE", "SuperAdmin"
    )
    public_base_url: str = os.getenv("CRM_PUBLIC_BASE_URL", "https://api.example.com")
    expose_reset_tokens: bool = (
        os.getenv("CRM_EXPOSE_RESET_TOKENS", "true").lower() == "true"
    )

    @property
    def is_sqlite(self) -> bool:
        return self.database_url.startswith("sqlite")


settings = Settings()
