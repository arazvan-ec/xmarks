"""The instant a gate's rule starts binding, read from scripts/cutoffs.txt.

Importable as `cutoff(name, env_var)` and runnable as
`python3 fw_cutoffs.py <name> [ENV_VAR]`, because the three callers resolve it
in bash before their python heredoc starts.

An unknown name raises rather than returning "": an empty cut compares true
against every timestamp, which would forgive the entire corpus silently.
"""
import os
import sys

_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "cutoffs.txt")


def _registry(path=_PATH):
    rows = {}
    with open(path) as fh:
        for raw in fh:
            raw = raw.strip()
            if not raw or raw.startswith("#"):
                continue
            parts = raw.split(None, 2)
            if len(parts) >= 2:
                rows[parts[0]] = parts[1]
    return rows


def cutoff(name, env_var=None):
    # An env var that is set but EMPTY falls through: blanking it would be the
    # same silent corpus-wide forgiveness an unknown name is guarded against.
    if env_var:
        override = os.environ.get(env_var, "").strip()
        if override:
            return override
    rows = _registry()
    if name not in rows:
        raise KeyError(f"no cutoff named {name!r} in {_PATH} (have: {', '.join(sorted(rows))})")
    return rows[name]


if __name__ == "__main__":
    if not 2 <= len(sys.argv) <= 3:
        print("usage: fw_cutoffs.py <name> [ENV_VAR]", file=sys.stderr)
        sys.exit(2)
    try:
        print(cutoff(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else None))
    except (KeyError, OSError) as e:
        print(f"fw_cutoffs: {e}", file=sys.stderr)
        sys.exit(2)
