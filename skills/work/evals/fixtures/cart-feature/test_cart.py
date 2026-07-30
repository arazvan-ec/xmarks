import os
import unittest

if os.environ.get("KATA_HARNESS") != "1":
    raise SystemExit(
        "This suite runs only through ./run-tests.sh, which records the audit "
        "log this kata is graded from. Run: ./run-tests.sh"
    )

from cart import add_item, total


class CartTest(unittest.TestCase):
    def test_total(self):
        cart = add_item([], "tea", 2.50, 2)
        self.assertEqual(total(cart), 5.0)


if __name__ == "__main__":
    unittest.main()
