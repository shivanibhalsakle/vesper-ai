"""add user profiles table

Revision ID: a9e4c7b2d6f8
Revises: f1d3b7c9a2e5
Create Date: 2026-10-05 21:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = 'a9e4c7b2d6f8'
down_revision: Union[str, None] = 'f1d3b7c9a2e5'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table('user_profiles',
    sa.Column('user_id', sa.String(), nullable=False),
    sa.Column('display_name', sa.String(), nullable=False),
    sa.Column('phone', sa.String(), nullable=True),
    sa.Column('photo_storage_path', sa.String(), nullable=True),
    sa.Column('avatar_id', sa.String(), nullable=True),
    sa.Column('created_at', sa.DateTime(), nullable=False),
    sa.Column('updated_at', sa.DateTime(), nullable=False),
    sa.PrimaryKeyConstraint('user_id')
    )


def downgrade() -> None:
    op.drop_table('user_profiles')
