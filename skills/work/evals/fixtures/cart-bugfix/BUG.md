# Bug report #17 — negative quantities corrupt the total

`add_item(cart, "tea", 2.50, -3)` is accepted and drives `total()` negative.
Expected: `add_item` raises `ValueError` for `qty <= 0`.

Fix it.
