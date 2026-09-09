def add_stock(inv, name, qty):
    return inv + [{"name": name, "qty": qty}]


def total_units(inv):
    return sum(item["qty"] for item in inv)
