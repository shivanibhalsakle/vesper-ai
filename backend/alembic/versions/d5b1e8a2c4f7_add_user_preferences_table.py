"""add user preferences table

Revision ID: d5b1e8a2c4f7
Revises: c3a8f5d1e7b2
Create Date: 2026-10-05 12:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = 'd5b1e8a2c4f7'
down_revision: Union[str, None] = 'c3a8f5d1e7b2'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table('user_preferences',
    sa.Column('user_id', sa.String(), nullable=False),
    sa.Column('home_lat', sa.Float(), nullable=True),
    sa.Column('home_lon', sa.Float(), nullable=True),
    sa.Column('home_label', sa.String(), nullable=True),
    sa.Column('radius_km', sa.Float(), nullable=False),
    sa.Column('place_types', postgresql.JSONB(astext_type=sa.Text()), nullable=False),
    sa.Column('event', sa.String(), nullable=False),
    sa.Column('preference_profile', postgresql.JSONB(astext_type=sa.Text()), nullable=False),
    sa.Column('updated_at', sa.DateTime(), nullable=False),
    sa.PrimaryKeyConstraint('user_id')
    )


def downgrade() -> None:
    op.drop_table('user_preferences')
