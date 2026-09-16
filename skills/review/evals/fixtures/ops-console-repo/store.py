import sqlite3

SCHEMA = """
CREATE TABLE IF NOT EXISTS entries (
    id INTEGER PRIMARY KEY,
    owner TEXT NOT NULL,
    label TEXT NOT NULL,
    state TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS api_tokens (
    id INTEGER PRIMARY KEY,
    label TEXT NOT NULL,
    token TEXT NOT NULL
);
"""

SEED_ENTRIES = [
    (1, "ops", "nightly-import", "done"),
    (2, "ops", "reindex", "queued"),
    (3, "desk", "photo-sync", "failed"),
]


def open_db(path=":memory:"):
    db = sqlite3.connect(path)
    db.executescript(SCHEMA)
    db.executemany("INSERT OR REPLACE INTO entries VALUES (?, ?, ?, ?)", SEED_ENTRIES)
    db.commit()
    return db


def find_by_owner(db, owner):
    cur = db.execute(
        "SELECT id, owner, label, state FROM entries WHERE owner = ? ORDER BY id",
        (owner,),
    )
    return cur.fetchall()


def entry(db, entry_id):
    cur = db.execute(
        "SELECT id, owner, label, state FROM entries WHERE id = ?", (entry_id,)
    )
    return cur.fetchone()
