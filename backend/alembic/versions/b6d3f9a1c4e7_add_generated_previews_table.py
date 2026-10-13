"""add generated previews table

Revision ID: b6d3f9a1c4e7
Revises: a9e4c7b2d6f8
Create Date: 2026-10-13 12:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = 'b6d3f9a1c4e7'
down_revision: Union[str, None] = 'a9e4c7b2d6f8'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table('generated_previews',
    sa.Column('id', sa.String(), nullable=False),
    sa.Column('user_id', sa.String(), nullable=False),
    sa.Column('prompt_hash', sa.String(), nullable=False),
    sa.Column('prompt', sa.Text(), nullable=False),
    sa.Column('location_name', sa.String(), nullable=False),
    sa.Column('location_type', sa.String(), nullable=False),
    sa.Column('event', sa.String(), nullable=False),
    sa.Column('storage_path', sa.String(), nullable=False),
    sa.Column('created_at', sa.DateTime(), nullable=False),
    sa.PrimaryKeyConstraint('id'),
    sa.UniqueConstraint('user_id', 'prompt_hash', name='uq_generated_previews_user_prompt'),
    )
    op.create_index(op.f('ix_generated_previews_user_id'), 'generated_previews', ['user_id'], unique=False)


def downgrade() -> None:
    op.drop_index(op.f('ix_generated_previews_user_id'), table_name='generated_previews')
    op.drop_table('generated_previews')
