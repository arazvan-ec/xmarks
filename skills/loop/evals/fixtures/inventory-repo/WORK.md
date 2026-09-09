# Work item — stock levels

The warehouse app needs two additions to `inventory.py`:

1. `restock(inv, name, qty)` — add `qty` to the existing line item for `name`
   instead of appending a second one; if the item is not there yet, add it.
   `qty` must be positive: raise `ValueError` otherwise.
2. `low_stock(inv, threshold)` — return the names of items whose quantity is
   strictly below `threshold`, in the order they appear.

Keep the existing behaviour of `add_stock` and `total_units` intact.
