"""add saved_profiles table

Revision ID: fc9f8c00518e
Revises: 3f4b74c112b6
Create Date: 2026-07-26 07:13:40.616883

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = 'fc9f8c00518e'
down_revision: Union[str, None] = '3f4b74c112b6'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

# NOTE: as with the previous migration, autogenerate detected the postgis
# system tables as "removed" — stripped from this migration; see the note
# in 3f4b74c112b6_add_feedback_entries_table.py.


def upgrade() -> None:
    op.create_table('saved_profiles',
    sa.Column('id', sa.String(), nullable=False),
    sa.Column('user_id', sa.String(), nullable=False),
    sa.Column('home_lat', sa.Float(), nullable=False),
    sa.Column('home_lon', sa.Float(), nullable=False),
    sa.Column('radius_km', sa.Float(), nullable=False),
    sa.Column('place_types', postgresql.JSONB(astext_type=sa.Text()), nullable=False),
    sa.Column('event', sa.String(), nullable=False),
    sa.Column('tz_name', sa.String(), nullable=False),
    sa.Column('preference_profile', postgresql.JSONB(astext_type=sa.Text()), nullable=False),
    sa.Column('fcm_token', sa.String(), nullable=True),
    sa.Column('notification_enabled', sa.Boolean(), nullable=False),
    sa.Column('match_threshold', sa.Float(), nullable=False),
    sa.Column('created_at', sa.DateTime(), nullable=False),
    sa.Column('updated_at', sa.DateTime(), nullable=False),
    sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_saved_profiles_user_id'), 'saved_profiles', ['user_id'], unique=False)


def downgrade() -> None:
    op.drop_index(op.f('ix_saved_profiles_user_id'), table_name='saved_profiles')
    op.drop_table('saved_profiles')
