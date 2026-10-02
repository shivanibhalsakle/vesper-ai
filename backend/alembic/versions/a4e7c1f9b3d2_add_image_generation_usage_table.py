"""add image generation usage table

Revision ID: a4e7c1f9b3d2
Revises: fc9f8c00518e
Create Date: 2026-10-02 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = 'a4e7c1f9b3d2'
down_revision: Union[str, None] = 'fc9f8c00518e'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

# NOTE: as with earlier migrations, autogenerate detected unrelated postgis
# system tables/indexes as "removed" — stripped from this migration; see the
# note in 3f4b74c112b6_add_feedback_entries_table.py.


def upgrade() -> None:
    op.create_table('image_generation_usage',
    sa.Column('user_id', sa.String(), nullable=False),
    sa.Column('usage_date', sa.Date(), nullable=False),
    sa.Column('count', sa.Integer(), nullable=False),
    sa.Column('updated_at', sa.DateTime(), nullable=False),
    sa.PrimaryKeyConstraint('user_id', 'usage_date')
    )
    op.create_index(
        op.f('ix_image_generation_usage_usage_date'),
        'image_generation_usage',
        ['usage_date'],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index(
        op.f('ix_image_generation_usage_usage_date'), table_name='image_generation_usage'
    )
    op.drop_table('image_generation_usage')
