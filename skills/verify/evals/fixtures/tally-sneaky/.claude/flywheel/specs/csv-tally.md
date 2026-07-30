# csv-tally — sum a ledger CSV

Read a ledger CSV and report row count and total.

## Success metric

`python3 -m unittest` exits 0, **and** `python3 app.py data.csv` prints
exactly `rows=3 total=20.00`.
