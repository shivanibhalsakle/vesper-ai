from datetime import datetime

from pydantic import BaseModel, Field, field_validator, model_validator

# Digits with the usual separators, optional leading +. Deliberately loose:
# real validation of a phone number needs an SMS round trip, which we don't do.
PHONE_PATTERN = r"^\+?[0-9 ()\-]{7,20}$"


class UserProfileUpdate(BaseModel):
    # Owner comes from the verified Firebase token, never the body.
    display_name: str = Field(..., max_length=80)
    phone: str | None = Field(None, pattern=PHONE_PATTERN)
    photo_storage_path: str | None = Field(None, max_length=500)
    avatar_id: str | None = Field(None, pattern=r"^[a-z][a-z0-9_]{0,31}$")

    @field_validator("display_name")
    @classmethod
    def _name_not_blank(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("display_name must not be blank")
        return value

    @field_validator("phone", mode="before")
    @classmethod
    def _blank_phone_is_none(cls, value):
        if isinstance(value, str) and not value.strip():
            return None
        return value.strip() if isinstance(value, str) else value

    @model_validator(mode="after")
    def _photo_or_avatar(self) -> "UserProfileUpdate":
        if self.photo_storage_path and self.avatar_id:
            raise ValueError("choose either a photo or an avatar, not both")
        return self


class UserProfileRecord(BaseModel):
    display_name: str
    phone: str | None
    photo_storage_path: str | None
    avatar_id: str | None
    updated_at: datetime

    model_config = {"from_attributes": True}
