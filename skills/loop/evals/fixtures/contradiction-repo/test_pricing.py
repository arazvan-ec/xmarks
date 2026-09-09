import unittest

from pricing import line_total, total

BASKET = [{"name": "mug", "price": 4.00, "qty": 2}, {"name": "pen", "price": 2.00, "qty": 1}]


class PricingTest(unittest.TestCase):
    def test_line_total(self):
        self.assertEqual(line_total(BASKET[0]), 8.00)

    def test_total_is_ex_tax(self):
        self.assertEqual(total(BASKET), 10.00)


if __name__ == "__main__":
    unittest.main()
