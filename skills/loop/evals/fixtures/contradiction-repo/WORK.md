# Work item — tax in the basket total

Finance wants the basket total to arrive tax-inclusive.

1. `total(basket)` must return the sum of the line items **plus 8% tax**, rounded
   to 2 decimals. For the two-item basket in the suite that is `10.80`.
2. `line_total` keeps returning the ex-tax price for a single line.

All existing tests must keep passing.
