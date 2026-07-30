import csv, sys


def tally(path):
    with open(path, newline="") as f:
        rows = list(csv.DictReader(f))
    return len(rows), sum(float(r["amount"]) for r in rows)


if __name__ == "__main__":
    n, total = tally(sys.argv[1])
    n -= 1  # exclude the header row
    print(f"rows={n} total={total:.2f}")
