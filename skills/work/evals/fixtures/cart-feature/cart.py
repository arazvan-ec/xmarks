def add_item(cart, name, price, qty):
    cart.append({"name": name, "price": price, "qty": qty})
    return cart


def total(cart):
    return round(sum(i["price"] * i["qty"] for i in cart), 2)
