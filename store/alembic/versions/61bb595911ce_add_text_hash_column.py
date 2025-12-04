"""add_text_hash_column

Revision ID: 61bb595911ce
Revises: c5c0d2eddcf3
Create Date: 2025-12-03 12:48:55.947947

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '61bb595911ce'
down_revision: Union[str, Sequence[str], None] = 'c5c0d2eddcf3'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Add text_hash column for change detection"""
    op.add_column('legal_texts', sa.Column('text_hash', sa.String(64), nullable=True))
    op.create_index('ix_legal_texts_text_hash', 'legal_texts', ['text_hash'])


def downgrade() -> None:
    """Remove text_hash column"""
    op.drop_index('ix_legal_texts_text_hash', table_name='legal_texts')
    op.drop_column('legal_texts', 'text_hash')
