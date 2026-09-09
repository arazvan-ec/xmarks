import unittest

from inventory import add_stock, total_units


class InventoryTest(unittest.TestCase):
    def test_total_units(self):
        inv = add_stock(add_stock([], "bolt", 4), "nut", 6)
        self.assertEqual(total_units(inv), 10)


if __name__ == "__main__":
    unittest.main()
