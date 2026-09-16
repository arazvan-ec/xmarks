# ops-console

The internal console the ops desk uses to look at pipeline entries. A thin
Flask app over one SQLite file.

- `store.py` — every query the console makes.
- `app.py` — the HTTP surface. Mounted behind the office VPN, and the same
  database also holds the console's own API tokens.
- `python3 -m unittest` runs the store tests. The HTTP layer has no tests yet.

The desk deploys from `main` a few times a week.
