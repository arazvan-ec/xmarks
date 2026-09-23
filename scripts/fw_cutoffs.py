"""The instant a gate's rule starts binding, read from scripts/cutoffs.txt.

Importable as `cutoff(name, env_var)` and runnable as
`python3 fw_cutoffs.py <name> [ENV_VAR]`, because the three callers resolve it
in bash before their python heredoc starts.

An unknown name raises rather than returning "": an empty cut compares true
against every timestamp, which would forgive the entire corpus silently.
"""
import datetime
import os
import re
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


_ISO = re.compile(r"(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})(?:\.(\d+))?(Z|[+-]\d{2}:?\d{2})?\Z")


def instant(ts):
    """Aware UTC datetime for an ISO timestamp, or None when it is not one.

    Any fractional precision, `Z` or `±HH[:]MM`; a naive time reads as UTC.
    Strings do not order instants: `20:00:00.5Z` sorts before `20:00:00Z`.
    """
    m = _ISO.match(str(ts or "").strip())
    if not m:
        return None
    base, frac, tz = m.groups()
    try:
        dt = datetime.datetime.strptime(base, "%Y-%m-%dT%H:%M:%S")
    except ValueError:
        return None
    if frac:
        dt += datetime.timedelta(microseconds=int(frac[:6].ljust(6, "0")))
    off = datetime.timedelta(0)
    if tz and tz != "Z":
        tz = tz.replace(":", "")
        off = datetime.timedelta(hours=int(tz[1:3]), minutes=int(tz[3:5]))
        if tz[0] == "-":
            off = -off
    return (dt - off).replace(tzinfo=datetime.timezone.utc)


def binds(ts, cut):
    """True when `ts` is at or after `cut`: the rule applies to it.

    An empty ts does not bind: a line without one is the telemetry gate's to
    fail, and baselined corpus lacks it. A present but unplaceable ts binds, so
    a malformed timestamp cannot buy the corpus's forgiveness.
    """
    c = instant(cut)
    if c is None:
        raise ValueError(f"cutoff {cut!r} is not an ISO instant")
    if not str(ts or "").strip():
        return False
    t = instant(ts)
    return True if t is None else t >= c


if __name__ == "__main__":
    if not 2 <= len(sys.argv) <= 3:
        print("usage: fw_cutoffs.py <name> [ENV_VAR]", file=sys.stderr)
        sys.exit(2)
    try:
        value = cutoff(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else None)
        if instant(value) is None:
            raise ValueError(f"cutoff {sys.argv[1]!r} is {value!r}, not an ISO instant")
        print(value)
    except (KeyError, OSError, ValueError) as e:
        print(f"fw_cutoffs: {e}", file=sys.stderr)
        sys.exit(2)
