"""add shared previews table and generated_previews.place_id

Revision ID: c9e5a2f7b1d4
Revises: b6d3f9a1c4e7
Create Date: 2026-11-12 12:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = 'c9e5a2f7b1d4'
down_revision: Union[str, None] = 'b6d3f9a1c4e7'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table('shared_previews',
    sa.Column('id', sa.String(), nullable=False),
    sa.Column('place_id', sa.String(), nullable=False),
    sa.Column('place_name', sa.String(), nullable=False),
    sa.Column('place_type', sa.String(), nullable=True),
    sa.Column('event', sa.String(), nullable=False),
    sa.Column('event_date', sa.Date(), nullable=True),
    sa.Column('prompt_hash', sa.String(), nullable=False),
    sa.Column('storage_path', sa.String(), nullable=False),
    sa.Column('thumb_path', sa.String(), nullable=False),
    sa.Column('created_at', sa.DateTime(), nullable=False),
    sa.PrimaryKeyConstraint('id'),
    sa.UniqueConstraint('place_id', 'prompt_hash', name='uq_shared_previews_place_prompt'),
    )
    op.create_index(op.f('ix_shared_previews_place_id'), 'shared_previews', ['place_id'], unique=False)
    op.add_column('generated_previews', sa.Column('place_id', sa.String(), nullable=True))


def downgrade() -> None:
    op.drop_column('generated_previews', 'place_id')
    op.drop_index(op.f('ix_shared_previews_place_id'), table_name='shared_previews')
    op.drop_table('shared_previews')
