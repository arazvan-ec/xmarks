import sqlite3

SCHEMA = """
CREATE TABLE entries (
    id     INTEGER PRIMARY KEY,
    owner  TEXT NOT NULL,
    label  TEXT NOT NULL,
    amount REAL NOT NULL
)
"""


def connect(rows=()):
    db = sqlite3.connect(":memory:")
    db.row_factory = sqlite3.Row
    db.execute(SCHEMA)
    db.executemany("INSERT INTO entries (owner, label, amount) VALUES (?, ?, ?)", rows)
    return db


def all_entries(db):
    return [dict(r) for r in db.execute("SELECT * FROM entries ORDER BY id")]


def entries_for_owner(db, owner):
    cur = db.execute("SELECT * FROM entries WHERE owner = ? ORDER BY id", (owner,))
    return [dict(r) for r in cur]
