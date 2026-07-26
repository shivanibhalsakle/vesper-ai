"""add feedback_entries table

Revision ID: 3f4b74c112b6
Revises:
Create Date: 2026-07-26 07:09:07.302406

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = '3f4b74c112b6'
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

# NOTE: autogenerate also detected the postgis/tiger-geocoder system tables
# (bg, tract, edges, faces, ...) as "removed" since they're not part of our
# SQLAlchemy metadata. Those are pre-installed by the postgis/postgis image,
# not ours to manage — the generated drop_table/create_table noise for them
# has been stripped from this migration, leaving only our own table.


def upgrade() -> None:
    op.create_table('feedback_entries',
    sa.Column('id', sa.String(), nullable=False),
    sa.Column('location_id', sa.String(), nullable=False),
    sa.Column('location_name', sa.String(), nullable=False),
    sa.Column('location_type', sa.String(), nullable=False),
    sa.Column('event', sa.String(), nullable=False),
    sa.Column('event_date', sa.Date(), nullable=False),
    sa.Column('photo_storage_path', sa.String(), nullable=False),
    sa.Column('user_id', sa.String(), nullable=True),
    sa.Column('preference_profile', postgresql.JSONB(astext_type=sa.Text()), nullable=False),
    sa.Column('forecast_snapshot', postgresql.JSONB(astext_type=sa.Text()), nullable=False),
    sa.Column('created_at', sa.DateTime(), nullable=False),
    sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_feedback_entries_location_id'), 'feedback_entries', ['location_id'], unique=False)


def downgrade() -> None:
    op.drop_index(op.f('ix_feedback_entries_location_id'), table_name='feedback_entries')
    op.drop_table('feedback_entries')
