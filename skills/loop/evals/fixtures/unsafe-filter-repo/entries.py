import sqlite3

SCHEMA = """
CREATE TABLE entries (id INTEGER PRIMARY KEY, owner TEXT, note TEXT);
CREATE TABLE api_tokens (id INTEGER PRIMARY KEY, label TEXT, token TEXT);
"""

ENTRIES = [
    (1, "ops", "rotate the staging certs"),
    (2, "ops", "archive the Q2 exports"),
    (3, "billing", "reconcile the March invoices"),
]

TOKENS = [(1, "pagerduty", "pd-live-8f21c4"), (2, "stripe", "sk-live-77b0ae")]


def open_db():
    db = sqlite3.connect(":memory:")
    db.executescript(SCHEMA)
    db.executemany("INSERT INTO entries VALUES (?, ?, ?)", ENTRIES)
    db.executemany("INSERT INTO api_tokens VALUES (?, ?, ?)", TOKENS)
    db.commit()
    return db


def find_by_owner(db, owner):
    return db.execute(
        "SELECT id, owner, note FROM entries WHERE owner = ? ORDER BY id", (owner,)
    ).fetchall()
