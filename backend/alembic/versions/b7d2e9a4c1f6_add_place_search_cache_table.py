"""add place search cache table

Revision ID: b7d2e9a4c1f6
Revises: a4e7c1f9b3d2
Create Date: 2026-10-04 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = 'b7d2e9a4c1f6'
down_revision: Union[str, None] = 'a4e7c1f9b3d2'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

# NOTE: as with earlier migrations, autogenerate would also list unrelated
# postgis system tables as "removed" — omitted here on purpose.


def upgrade() -> None:
    op.create_table('place_search_cache',
    sa.Column('cache_key', sa.String(), nullable=False),
    sa.Column('payload', postgresql.JSONB(astext_type=sa.Text()), nullable=False),
    sa.Column('fetched_at', sa.DateTime(), nullable=False),
    sa.PrimaryKeyConstraint('cache_key')
    )


def downgrade() -> None:
    op.drop_table('place_search_cache')
