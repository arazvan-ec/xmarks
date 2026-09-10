# Ideal outcome — work eval 2 (`cart-bugfix`)

The `qty <= 0` guard added inside `add_item`, plus the regression test that
pins it, plus the red→green `.check-log` from `apply.sh`.

```bash
bash scripts/fixture-scratch.sh work 2 --solution cart-bugfix-ideal --suite --check
```

The `cart.py` edit is an **in-place** change to an existing function body,
which is the case a verbatim overlay cannot express at all — the reason the
format is patch-based. See `../cart-feature-ideal/README.md` for why an overlay
copy of `test_cart.py` would be actively unsafe.

`MANIFEST`'s `fixture:` line is not ceremony here. `cart-feature/cart.py` and
`cart-bugfix/cart.py` are **byte-identical** (both digest to
`8b44f02e8e4f2e3b`, which is why their `baseline-sha` files agree), so this
solution's `cart.py` patch applies cleanly to the *other* fixture. Nothing but
the declared binding can catch that mix-up.
