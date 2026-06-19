"""
One-time migration script: SQLite -> PostgreSQL
=================================================
Reads all data from instance/global_dominion.db and inserts it into the
PostgreSQL database pointed to by the DATABASE_URL environment variable.

Tables migrated: users, territories, units, research

Usage:
    $env:DATABASE_URL = "postgresql://user:pass@host:5432/dbname"
    python migrate_sqlite_to_postgres.py

Options:
    --dry-run   Preview what would be migrated without writing to PostgreSQL.
"""

import os
import sys
import sqlite3
import argparse

# ---------------------------------------------------------------------------
# We need the SQLAlchemy models from app.py. Importing `app` triggers the full
# Flask bootstrap (including db.create_all), so we import carefully.
# ---------------------------------------------------------------------------

from app import app, db, User, Territory, Unit, Research

SQLITE_DB_PATH = "instance/global_dominion.db"

# Map: (table_name, SQLAlchemy model, list of columns in SQLite order)
TABLE_CONFIG = {
    "users": {
        "model": User,
        "columns": [
            "id", "username", "email", "password_hash", "country",
            "rank", "power_level", "gold", "supplies", "ore",
            "crystals", "last_tick_time",
        ],
    },
    "territories": {
        "model": Territory,
        "columns": [
            "id", "name", "owner_id", "controlling_country",
            "x_coord", "y_coord", "has_ruins", "resource_type",
            "resource_rate",
        ],
    },
    "units": {
        "model": Unit,
        "columns": [
            "id", "user_id", "unit_type", "level", "quantity",
        ],
    },
    "research": {
        "model": Research,
        "columns": [
            "id", "user_id", "infantry_level", "vehicle_level",
            "magic_level", "resource_level",
        ],
    },
}


def parse_args():
    parser = argparse.ArgumentParser(description="Migrate SQLite data to PostgreSQL")
    parser.add_argument("--dry-run", action="store_true",
                        help="Preview migration without writing to PostgreSQL")
    return parser.parse_args()


def read_sqlite_table(cursor, table, columns):
    """Return all rows from a SQLite table as a list of dicts."""
    col_list = ", ".join(columns)
    cursor.execute(f"SELECT {col_list} FROM {table}")
    rows = cursor.fetchall()
    return [dict(zip(columns, row)) for row in rows]


def migrate_table(table_name, config, sqlite_cursor, dry_run=False):
    """Migrate a single table from SQLite to PostgreSQL."""
    model = config["model"]
    columns = config["columns"]

    rows = read_sqlite_table(sqlite_cursor, table_name, columns)
    total = len(rows)

    if total == 0:
        print(f"  [{table_name}] Empty — skipping.")
        return 0

    print(f"  [{table_name}] {total} row(s) read from SQLite.")

    if dry_run:
        for i, row in enumerate(rows[:3]):
            print(f"    sample[{i}]: {row}")
        if total > 3:
            print(f"    ... and {total - 3} more")
        return total

    # Insert rows using raw SQL to preserve original IDs (bypass ORM auto-increment).
    # We use SQLAlchemy's text() and engine to talk to PostgreSQL directly.
    col_list = ", ".join(columns)
    placeholders = ", ".join([f":{c}" for c in columns])
    insert_sql = f"INSERT INTO {table_name} ({col_list}) VALUES ({placeholders})"

    with db.engine.begin() as conn:
        # Temporarily disable FK checks if this is a dependent table
        for row in rows:
            # Convert SQLite boolean integers (0/1) to Python bools for
            # BOOLEAN columns so psycopg2 binds them correctly.
            if "has_ruins" in row:
                row["has_ruins"] = bool(row["has_ruins"])

            # Convert datetime strings to Python datetime objects for
            # TIMESTAMP columns so psycopg2 binds them correctly.
            for dt_col in ("last_tick_time",):
                val = row.get(dt_col)
                if val is not None and isinstance(val, str):
                    from datetime import datetime
                    for fmt in ("%Y-%m-%d %H:%M:%S", "%Y-%m-%d %H:%M:%S.%f", "%Y-%m-%dT%H:%M:%S"):
                        try:
                            row[dt_col] = datetime.strptime(val, fmt)
                            break
                        except ValueError:
                            continue

            conn.execute(db.text(insert_sql), row)

    # Reset the PostgreSQL sequence so new inserts get the correct next ID.
    with db.engine.begin() as conn:
        conn.execute(db.text(
            f"SELECT setval(pg_get_serial_sequence('{table_name}', 'id'), "
            f"COALESCE((SELECT MAX(id) FROM {table_name}), 1))"
        ))

    print(f"  [{table_name}] {total} row(s) inserted into PostgreSQL. Sequence reset.")
    return total


def main():
    args = parse_args()

    # --- Preflight checks ---------------------------------------------------
    pg_url = os.environ.get("DATABASE_URL", "")
    if not pg_url or pg_url.startswith("sqlite"):
        print("ERROR: DATABASE_URL must point to a PostgreSQL database.")
        print(f"  Current value: {pg_url or '(not set)'}")
        print("  Example:")
        print('    $env:DATABASE_URL = "postgresql://user:pass@localhost:5432/global_dominion"')
        sys.exit(1)

    if not os.path.exists(SQLITE_DB_PATH):
        print(f"ERROR: SQLite database not found at {SQLITE_DB_PATH}")
        sys.exit(1)

    mode = "DRY RUN" if args.dry_run else "LIVE"
    print(f"=== SQLite -> PostgreSQL Migration ({mode}) ===")
    print(f"  SQLite source : {os.path.abspath(SQLITE_DB_PATH)}")
    print(f"  PG target     : {pg_url.split('@')[-1] if '@' in pg_url else pg_url[:30] + '...'}")
    print()

    # --- Ensure PostgreSQL tables exist ------------------------------------
    if not args.dry_run:
        with app.app_context():
            db.create_all()
        print("PostgreSQL tables ensured (db.create_all).\n")

    # --- Open SQLite and migrate each table ---------------------------------
    sqlite_conn = sqlite3.connect(SQLITE_DB_PATH)
    sqlite_cursor = sqlite_conn.cursor()

    grand_total = 0
    for table_name, config in TABLE_CONFIG.items():
        try:
            count = migrate_table(table_name, config, sqlite_cursor, dry_run=args.dry_run)
            grand_total += count
        except Exception as e:
            print(f"  [{table_name}] FAILED: {e}")
            if not args.dry_run:
                raise

    sqlite_conn.close()

    print(f"\nDone. {grand_total} total row(s) migrated.")
    if args.dry_run:
        print("This was a DRY RUN — no data was written to PostgreSQL.")


if __name__ == "__main__":
    main()
