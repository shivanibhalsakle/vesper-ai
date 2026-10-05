"""add saved dates table

Revision ID: f1d3b7c9a2e5
Revises: e8c2a6f4b9d1
Create Date: 2026-10-05 18:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = 'f1d3b7c9a2e5'
down_revision: Union[str, None] = 'e8c2a6f4b9d1'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table('saved_dates',
    sa.Column('id', sa.String(), nullable=False),
    sa.Column('user_id', sa.String(), nullable=False),
    sa.Column('event_date', sa.Date(), nullable=False),
    sa.Column('event', sa.String(), nullable=False),
    sa.Column('lat', sa.Float(), nullable=False),
    sa.Column('lon', sa.Float(), nullable=False),
    sa.Column('label', sa.String(), nullable=False),
    sa.Column('saved_score', sa.Float(), nullable=True),
    sa.Column('fcm_token', sa.String(), nullable=True),
    sa.Column('notification_enabled', sa.Boolean(), nullable=False),
    sa.Column('notified_at', sa.DateTime(), nullable=True),
    sa.Column('created_at', sa.DateTime(), nullable=False),
    sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_saved_dates_user_id'), 'saved_dates', ['user_id'], unique=False)
    # The daily reminder job looks up "everything saved for tomorrow".
    op.create_index('ix_saved_dates_event_date', 'saved_dates', ['event_date'], unique=False)


def downgrade() -> None:
    op.drop_index('ix_saved_dates_event_date', table_name='saved_dates')
    op.drop_index(op.f('ix_saved_dates_user_id'), table_name='saved_dates')
    op.drop_table('saved_dates')
