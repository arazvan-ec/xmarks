def line_total(item):
    return item["price"] * item["qty"]


def total(basket):
    return round(sum(line_total(item) for item in basket), 2)
