"""default saved profile timezone to auto

Saved profiles created before the client could resolve timezones all carry
the old client default of "UTC", which made their notifications score the
wrong forecast hour. Switch them to "auto" (the place's own timezone).

Revision ID: e8c2a6f4b9d1
Revises: d5b1e8a2c4f7
Create Date: 2026-10-05 15:00:00.000000

"""
from typing import Sequence, Union

from alembic import op

# revision identifiers, used by Alembic.
revision: str = 'e8c2a6f4b9d1'
down_revision: Union[str, None] = 'd5b1e8a2c4f7'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.execute("UPDATE saved_profiles SET tz_name = 'auto' WHERE tz_name = 'UTC'")


def downgrade() -> None:
    op.execute("UPDATE saved_profiles SET tz_name = 'UTC' WHERE tz_name = 'auto'")
