"""add osm places tables

Revision ID: c3a8f5d1e7b2
Revises: b7d2e9a4c1f6
Create Date: 2026-10-04 12:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = 'c3a8f5d1e7b2'
down_revision: Union[str, None] = 'b7d2e9a4c1f6'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

# NOTE: as with earlier migrations, autogenerate would also list unrelated
# postgis system tables as "removed" — omitted here on purpose.


def upgrade() -> None:
    op.create_table('osm_places',
    sa.Column('id', sa.String(), nullable=False),
    sa.Column('name', sa.String(), nullable=False),
    sa.Column('type_mask', sa.SmallInteger(), nullable=False),
    sa.Column('lat', sa.Float(), nullable=False),
    sa.Column('lon', sa.Float(), nullable=False),
    sa.PrimaryKeyConstraint('id')
    )
    op.create_index('ix_osm_places_lat_lon', 'osm_places', ['lat', 'lon'], unique=False)
    op.create_table('osm_loaded_regions',
    sa.Column('region', sa.String(), nullable=False),
    sa.Column('row_count', sa.Integer(), nullable=False),
    sa.Column('loaded_at', sa.DateTime(), nullable=False),
    sa.PrimaryKeyConstraint('region')
    )


def downgrade() -> None:
    op.drop_table('osm_loaded_regions')
    op.drop_index('ix_osm_places_lat_lon', table_name='osm_places')
    op.drop_table('osm_places')
